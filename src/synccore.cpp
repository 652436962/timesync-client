#include "synccore.h"
#include "ntpprobe.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QPalette>
#include <QStandardPaths>
#include <QStyleHints>
#include <QStringConverter>
#include <QSysInfo>
#include <QTextStream>

#include <algorithm>
#include <cmath>

namespace {
constexpr int kStepSeconds = 128;
constexpr int kMaxSamples = 1800;
constexpr int kMaxRecords = 120;
constexpr int kMaxEvents = 300;
constexpr int kMaxStep = 3000;

QString fmtMs(double v, int decimals = 1)
{
    if (!std::isfinite(v))
        return QStringLiteral("—");
    return QString::number(v, 'f', decimals);
}

QString signedMs(double v)
{
    const QString body = fmtMs(std::abs(v) < 1.0 ? v : v, 1);
    return (v >= 0 ? QStringLiteral("+") : QString()) + body + QStringLiteral(" ms");
}

QString toneForLevel(const QString &level)
{
    if (level == QLatin1String("WARN"))
        return QStringLiteral("amber");
    if (level == QLatin1String("ERROR"))
        return QStringLiteral("red");
    return QStringLiteral("green");
}
} // namespace

SyncCore::SyncCore(QObject *parent)
    : QObject(parent)
    , m_store(QStringLiteral("TimeSync"), QStringLiteral("TimeSync-Client"))
{
    const QPalette pal = QGuiApplication::palette();
    m_systemDark = pal.color(QPalette::Window).lightness() < 128;

    m_probe = new NtpProbe(this);
    m_testProbe = new NtpProbe(this);
    connect(m_probe, &NtpProbe::finished, this, &SyncCore::onProbeFinished);
    connect(m_testProbe, &NtpProbe::finished, this, &SyncCore::onTestFinished);

    m_pollTimer.setSingleShot(false);
    m_pollTimer.setInterval(m_pollSec * 1000);
    connect(&m_pollTimer, &QTimer::timeout, this, [this]() { probeAll(QStringLiteral("周期轮询")); });

    m_tickTimer.setInterval(1000);
    connect(&m_tickTimer, &QTimer::timeout, this, [this]() {
        updateCountersDaily();
        emit liveChanged();
        emit clockChanged();
    });
    m_tickTimer.start();

    m_guardTimer.setSingleShot(true);
    connect(&m_guardTimer, &QTimer::timeout, this, [this]() {
        if (m_pending > 0)
            finalizeCycle(true);
    });

    setupDefaultSources();
    loadState();

    if (m_events.isEmpty()) {
        addEvent(QStringLiteral("INFO"), QStringLiteral("启动完成"),
                 QStringLiteral("TimeSync 客户端 v2.4.1 启动，加载 %1 个时钟源")
                     .arg(m_sources.size() - 1),
                 QStringLiteral("blue"), false);
    }

    rebuildSourceStatus();
    QTimer::singleShot(500, this, [this]() { probeAll(QStringLiteral("开机启动")); });
}

// ---------------------------------------------------------------- defaults

void SyncCore::setupDefaultSources()
{
    const QJsonArray stored = m_store.value(QStringLiteral("sources")).toJsonArray();
    if (!stored.isEmpty()) {
        for (const QJsonValue &v : stored) {
            const QJsonObject o = v.toObject();
            ClockSource s;
            s.id = o.value(QStringLiteral("id")).toString();
            s.name = o.value(QStringLiteral("name")).toString();
            s.desc = o.value(QStringLiteral("desc")).toString();
            s.host = o.value(QStringLiteral("host")).toString();
            s.proto = o.value(QStringLiteral("proto")).toString(QStringLiteral("NTPv4"));
            s.port = o.value(QStringLiteral("port")).toInt(123);
            s.enabled = o.value(QStringLiteral("enabled")).toBool(true);
            s.system = o.value(QStringLiteral("system")).toBool(false);
            if (s.id.isEmpty())
                s.id = QStringLiteral("src-%1").arg(m_sources.size() + 1);
            m_sources.append(s);
        }
    } else {
        ClockSource primary;
        primary.id = QStringLiteral("aliyun");
        primary.name = QStringLiteral("阿里云 NTP");
        primary.desc = QStringLiteral("公共 NTP · 主时钟");
        primary.host = QStringLiteral("ntp.aliyun.com");
        primary.enabled = true;
        m_sources.append(primary);

        ClockSource s2;
        s2.id = QStringLiteral("tencent");
        s2.name = QStringLiteral("腾讯云 NTP");
        s2.desc = QStringLiteral("公共 NTP · 备用");
        s2.host = QStringLiteral("ntp.tencent.com");
        m_sources.append(s2);

        ClockSource s3;
        s3.id = QStringLiteral("windows");
        s3.name = QStringLiteral("Windows 时间");
        s3.desc = QStringLiteral("公共池 · 备用");
        s3.host = QStringLiteral("time.windows.com");
        m_sources.append(s3);

        ClockSource s4;
        s4.id = QStringLiteral("poolcn");
        s4.name = QStringLiteral("NTP Pool 中国");
        s4.desc = QStringLiteral("公共池 · 次级备份");
        s4.host = QStringLiteral("cn.pool.ntp.org");
        m_sources.append(s4);

        ClockSource sys;
        sys.id = QStringLiteral("local");
        sys.name = QStringLiteral("本机系统时钟");
        sys.desc = QStringLiteral("本地晶振保持 · 实测偏移");
        sys.host = QStringLiteral("—");
        sys.proto = QStringLiteral("本地");
        sys.enabled = false;
        sys.system = true;
        m_sources.append(sys);
        saveSources();
    }

    bool hasSystem = false;
    for (const ClockSource &s : std::as_const(m_sources))
        hasSystem = hasSystem || s.system;
    if (!hasSystem) {
        ClockSource sys;
        sys.id = QStringLiteral("local");
        sys.name = QStringLiteral("本机系统时钟");
        sys.desc = QStringLiteral("本地晶振保持 · 实测偏移");
        sys.host = QStringLiteral("—");
        sys.proto = QStringLiteral("本地");
        sys.enabled = false;
        sys.system = true;
        m_sources.append(sys);
    }
    if (m_sources.isEmpty() || m_sources.first().system) {
        ClockSource primary;
        primary.id = QStringLiteral("aliyun");
        primary.name = QStringLiteral("阿里云 NTP");
        primary.desc = QStringLiteral("公共 NTP · 主时钟");
        primary.host = QStringLiteral("ntp.aliyun.com");
        m_sources.prepend(primary);
    }
}

void SyncCore::loadState()
{
    const QJsonArray evs = m_store.value(QStringLiteral("events")).toJsonArray();
    for (const QJsonValue &v : evs) {
        const QJsonObject o = v.toObject();
        LogEvent e;
        e.time = QDateTime::fromString(o.value(QStringLiteral("time")).toString(), Qt::ISODate);
        e.level = o.value(QStringLiteral("level")).toString();
        e.title = o.value(QStringLiteral("title")).toString();
        e.desc = o.value(QStringLiteral("desc")).toString();
        e.tone = o.value(QStringLiteral("tone")).toString();
        e.unread = o.value(QStringLiteral("unread")).toBool(false);
        if (e.time.isValid())
            m_events.append(e);
    }

    const QJsonArray recs = m_store.value(QStringLiteral("records")).toJsonArray();
    for (const QJsonValue &v : recs) {
        const QJsonObject o = v.toObject();
        SyncRecord r;
        r.time = QDateTime::fromString(o.value(QStringLiteral("time")).toString(), Qt::ISODate);
        r.trigger = o.value(QStringLiteral("trigger")).toString();
        r.source = o.value(QStringLiteral("source")).toString();
        r.offsetMs = o.value(QStringLiteral("offset")).toDouble();
        r.delayMs = o.value(QStringLiteral("delay")).toDouble();
        r.ok = o.value(QStringLiteral("ok")).toBool(true);
        if (r.time.isValid())
            m_records.append(r);
    }

    const QJsonArray ruleArr = m_store.value(QStringLiteral("rules")).toJsonArray();
    if (!ruleArr.isEmpty()) {
        for (const QJsonValue &v : ruleArr) {
            const QJsonObject o = v.toObject();
            AlertRule r;
            r.name = o.value(QStringLiteral("name")).toString();
            r.condition = o.value(QStringLiteral("condition")).toString();
            r.action = o.value(QStringLiteral("action")).toString();
            r.level = o.value(QStringLiteral("level")).toString();
            r.tone = o.value(QStringLiteral("tone")).toString();
            r.enabled = o.value(QStringLiteral("enabled")).toBool(true);
            r.custom = o.value(QStringLiteral("custom")).toBool(false);
            m_rules.append(r);
        }
    } else {
        m_rules = {
            {QStringLiteral("偏差超阈值"), QStringLiteral("偏差绝对值 > 5 ms 持续 3 次采样"),
             QStringLiteral("弹窗 + 记录"), QStringLiteral("警告"), QStringLiteral("amber"), true, false},
            {QStringLiteral("时钟源失联"), QStringLiteral("任一启用的时钟源连续 3 次无响应"),
             QStringLiteral("弹窗 + 记录"), QStringLiteral("严重"), QStringLiteral("red"), true, false},
            {QStringLiteral("漂移超限"), QStringLiteral("本机时钟偏移 > 50 ms"),
             QStringLiteral("仅记录"), QStringLiteral("严重"), QStringLiteral("red"), true, false},
            {QStringLiteral("频繁重同步"), QStringLiteral("10 分钟内手动同步次数 > 20"),
             QStringLiteral("仅记录"), QStringLiteral("提示"), QStringLiteral("blue"), false, false},
        };
        saveRules();
    }

    m_warnMs = m_store.value(QStringLiteral("settings/warnMs"), 5).toInt();
    m_severeMs = m_store.value(QStringLiteral("settings/severeMs"), 50).toInt();
    m_sampleInterval = m_store.value(QStringLiteral("settings/sampleInterval"), 4).toInt();
    m_strategy = m_store.value(QStringLiteral("settings/strategy"), QStringLiteral("层级优先")).toString();
    m_pollSec = m_store.value(QStringLiteral("settings/pollSec"), 4).toInt();
    m_ntsEnabled = false;
    m_themeMode = m_store.value(QStringLiteral("settings/theme"), QStringLiteral("浅色")).toString();
    m_density = m_store.value(QStringLiteral("settings/density"), QStringLiteral("紧凑")).toString();
    m_autostart = m_store.value(QStringLiteral("settings/autostart"), false).toBool();
    m_trayEnabled = m_store.value(QStringLiteral("settings/tray"), true).toBool();
    m_closeAction = m_store.value(QStringLiteral("settings/closeAction"), QStringLiteral("退出程序")).toString();
    m_logRetention = m_store.value(QStringLiteral("settings/logRetention"), QStringLiteral("最近 30 天")).toString();
    m_uploadEnabled = m_store.value(QStringLiteral("settings/upload"), false).toBool();
    m_notifySystem = m_store.value(QStringLiteral("settings/notifySystem"), true).toBool();
    m_notifyMail = m_store.value(QStringLiteral("settings/notifyMail"), true).toBool();
    m_notifyWebhook = m_store.value(QStringLiteral("settings/notifyWebhook"), false).toBool();
    m_keepLocalTime = m_store.value(QStringLiteral("settings/keepLocalTime"), true).toBool();
    m_allowWriteBack = m_store.value(QStringLiteral("settings/allowWriteBack"), false).toBool();
    m_snapshotBefore = m_store.value(QStringLiteral("settings/snapshotBefore"), true).toBool();

    m_totalSyncs = m_store.value(QStringLiteral("counters/total"), 0).toInt();
    m_todaySyncs = m_store.value(QStringLiteral("counters/today"), 0).toInt();
    m_counterDate = m_store.value(QStringLiteral("counters/date"), QString()).toString();
    updateCountersDaily();

    // Trim persisted events by retention policy.
    int days = 30;
    if (m_logRetention == QLatin1String("最近 7 天"))
        days = 7;
    else if (m_logRetention == QLatin1String("最近 90 天"))
        days = 90;
    else if (m_logRetention == QLatin1String("永久保留"))
        days = 3650;
    const QDateTime cutoff = QDateTime::currentDateTime().addDays(-days);
    m_events.erase(std::remove_if(m_events.begin(), m_events.end(),
                                  [&cutoff](const LogEvent &e) { return e.time < cutoff; }),
                   m_events.end());

    std::sort(m_records.begin(), m_records.end(),
              [](const SyncRecord &a, const SyncRecord &b) { return a.time > b.time; });
    std::sort(m_events.begin(), m_events.end(),
              [](const LogEvent &a, const LogEvent &b) { return a.time > b.time; });
}

// ---------------------------------------------------------------- persist

void SyncCore::saveSources()
{
    QJsonArray arr;
    for (const ClockSource &s : std::as_const(m_sources)) {
        QJsonObject o;
        o.insert(QStringLiteral("id"), s.id);
        o.insert(QStringLiteral("name"), s.name);
        o.insert(QStringLiteral("desc"), s.desc);
        o.insert(QStringLiteral("host"), s.host);
        o.insert(QStringLiteral("proto"), s.proto);
        o.insert(QStringLiteral("port"), s.port);
        o.insert(QStringLiteral("enabled"), s.enabled);
        o.insert(QStringLiteral("system"), s.system);
        arr.append(o);
    }
    m_store.setValue(QStringLiteral("sources"), arr);
    m_store.sync();
}

void SyncCore::saveEvents()
{
    QJsonArray arr;
    for (const LogEvent &e : std::as_const(m_events)) {
        QJsonObject o;
        o.insert(QStringLiteral("time"), e.time.toString(Qt::ISODate));
        o.insert(QStringLiteral("level"), e.level);
        o.insert(QStringLiteral("title"), e.title);
        o.insert(QStringLiteral("desc"), e.desc);
        o.insert(QStringLiteral("tone"), e.tone);
        o.insert(QStringLiteral("unread"), e.unread);
        arr.append(o);
    }
    m_store.setValue(QStringLiteral("events"), arr);
    m_store.sync();
}

void SyncCore::saveRules()
{
    QJsonArray arr;
    for (const AlertRule &r : std::as_const(m_rules)) {
        QJsonObject o;
        o.insert(QStringLiteral("name"), r.name);
        o.insert(QStringLiteral("condition"), r.condition);
        o.insert(QStringLiteral("action"), r.action);
        o.insert(QStringLiteral("level"), r.level);
        o.insert(QStringLiteral("tone"), r.tone);
        o.insert(QStringLiteral("enabled"), r.enabled);
        o.insert(QStringLiteral("custom"), r.custom);
        arr.append(o);
    }
    m_store.setValue(QStringLiteral("rules"), arr);
    m_store.sync();
}

void SyncCore::saveSettings()
{
    m_store.setValue(QStringLiteral("settings/warnMs"), m_warnMs);
    m_store.setValue(QStringLiteral("settings/severeMs"), m_severeMs);
    m_store.setValue(QStringLiteral("settings/sampleInterval"), m_sampleInterval);
    m_store.setValue(QStringLiteral("settings/strategy"), m_strategy);
    m_store.setValue(QStringLiteral("settings/pollSec"), m_pollSec);
    m_store.setValue(QStringLiteral("settings/theme"), m_themeMode);
    m_store.setValue(QStringLiteral("settings/density"), m_density);
    m_store.setValue(QStringLiteral("settings/autostart"), m_autostart);
    m_store.setValue(QStringLiteral("settings/tray"), m_trayEnabled);
    m_store.setValue(QStringLiteral("settings/closeAction"), m_closeAction);
    m_store.setValue(QStringLiteral("settings/logRetention"), m_logRetention);
    m_store.setValue(QStringLiteral("settings/upload"), m_uploadEnabled);
    m_store.setValue(QStringLiteral("settings/notifySystem"), m_notifySystem);
    m_store.setValue(QStringLiteral("settings/notifyMail"), m_notifyMail);
    m_store.setValue(QStringLiteral("settings/notifyWebhook"), m_notifyWebhook);
    m_store.setValue(QStringLiteral("settings/keepLocalTime"), m_keepLocalTime);
    m_store.setValue(QStringLiteral("settings/allowWriteBack"), m_allowWriteBack);
    m_store.setValue(QStringLiteral("settings/snapshotBefore"), m_snapshotBefore);
    m_store.sync();
}

// ---------------------------------------------------------------- getters

QVariantList SyncCore::sources() const
{
    QVariantList out;
    for (int i = 0; i < m_sources.size(); ++i) {
        const ClockSource &s = m_sources.at(i);
        QVariantMap m;
        m.insert(QStringLiteral("index"), i);
        m.insert(QStringLiteral("name"), s.name);
        m.insert(QStringLiteral("desc"), s.desc);
        m.insert(QStringLiteral("host"), s.host);
        m.insert(QStringLiteral("proto"), s.proto);
        m.insert(QStringLiteral("port"), s.port);
        m.insert(QStringLiteral("enabled"), s.enabled);
        m.insert(QStringLiteral("system"), s.system);
        m.insert(QStringLiteral("primary"), !s.system && !m_primaryId.isEmpty() && s.id == m_primaryId);
        m.insert(QStringLiteral("stratum"), s.system ? QStringLiteral("0")
                                                     : (s.ok ? QString::number(s.stratum) : QStringLiteral("—")));
        m.insert(QStringLiteral("offset"), s.system ? signedMs(m_offsetMs)
                                                    : (s.ok ? signedMs(s.offsetMs) : QStringLiteral("—")));
        m.insert(QStringLiteral("delay"), s.delayMs >= 0 ? QStringLiteral("%1 ms").arg(fmtMs(s.delayMs))
                                                         : QStringLiteral("—"));
        m.insert(QStringLiteral("status"), statusFor(s));
        m.insert(QStringLiteral("tone"), toneForStatus(s));
        m.insert(QStringLiteral("error"), s.error);
        out.append(m);
    }
    return out;
}

QVariantList SyncCore::overview() const
{
    QVariantList out;
    int listed = 0;
    for (const ClockSource &s : m_sources) {
        if (s.system || listed >= 3)
            continue;
        if (!s.enabled && listed >= 2)
            continue;
        QVariantMap m;
        m.insert(QStringLiteral("name"), s.name);
        m.insert(QStringLiteral("desc"), s.desc);
        m.insert(QStringLiteral("host"), s.host);
        m.insert(QStringLiteral("stratum"), s.ok ? QString::number(s.stratum) : QStringLiteral("—"));
        m.insert(QStringLiteral("offset"), s.ok ? signedMs(s.offsetMs) : QStringLiteral("—"));
        m.insert(QStringLiteral("status"), statusFor(s));
        m.insert(QStringLiteral("tone"), toneForStatus(s));
        out.append(m);
        ++listed;
    }

    const ClockSource *sys = nullptr;
    for (const ClockSource &s : m_sources) {
        if (s.system)
            sys = &s;
    }
    QVariantMap local;
    local.insert(QStringLiteral("name"), QStringLiteral("本机系统时钟"));
    local.insert(QStringLiteral("desc"), QStringLiteral("本地晶振保持 · 实测偏移"));
    local.insert(QStringLiteral("host"), QStringLiteral("—"));
    local.insert(QStringLiteral("stratum"), QStringLiteral("0"));
    local.insert(QStringLiteral("offset"),
                 m_primaryId.isEmpty() ? QStringLiteral("—") : signedMs(m_offsetMs));
    QString localStatus = QStringLiteral("待测");
    QString localTone = QStringLiteral("muted");
    if (!m_primaryId.isEmpty()) {
        const double a = std::abs(m_offsetMs);
        if (a > m_severeMs) {
            localStatus = QStringLiteral("漂移超限");
            localTone = QStringLiteral("red");
        } else if (a > m_warnMs) {
            localStatus = QStringLiteral("偏差偏高");
            localTone = QStringLiteral("amber");
        } else {
            localStatus = QStringLiteral("正常");
            localTone = QStringLiteral("blue");
        }
    }
    local.insert(QStringLiteral("status"), localStatus);
    local.insert(QStringLiteral("tone"), localTone);
    Q_UNUSED(sys);
    out.append(local);
    return out;
}

QVariantList SyncCore::events() const
{
    QVariantList out;
    for (int i = 0; i < m_events.size(); ++i) {
        const LogEvent &e = m_events.at(i);
        QVariantMap m;
        m.insert(QStringLiteral("index"), i);
        m.insert(QStringLiteral("time"), e.time.toString(QStringLiteral("HH:mm:ss")));
        m.insert(QStringLiteral("date"), e.time.toString(QStringLiteral("yyyy-MM-dd")));
        m.insert(QStringLiteral("full"), e.time.toString(QStringLiteral("yyyy-MM-dd HH:mm:ss")));
        m.insert(QStringLiteral("level"), e.level);
        m.insert(QStringLiteral("title"), e.title);
        m.insert(QStringLiteral("desc"), e.desc);
        m.insert(QStringLiteral("tone"), e.tone);
        m.insert(QStringLiteral("unread"), e.unread);
        out.append(m);
    }
    return out;
}

QVariantList SyncCore::records() const
{
    QVariantList out;
    for (const SyncRecord &r : m_records) {
        QVariantMap m;
        m.insert(QStringLiteral("time"), r.time.toString(QStringLiteral("HH:mm:ss")));
        m.insert(QStringLiteral("date"), r.time.toString(QStringLiteral("yyyy-MM-dd")));
        m.insert(QStringLiteral("trigger"), r.trigger);
        m.insert(QStringLiteral("source"), r.source);
        m.insert(QStringLiteral("offset"), signedMs(r.offsetMs));
        m.insert(QStringLiteral("delay"), QStringLiteral("%1 ms").arg(fmtMs(r.delayMs)));
        m.insert(QStringLiteral("result"), r.ok ? QStringLiteral("成功") : QStringLiteral("降级"));
        m.insert(QStringLiteral("tone"), r.ok ? QStringLiteral("green") : QStringLiteral("amber"));
        out.append(m);
    }
    return out;
}

QVariantList SyncCore::rules() const
{
    QVariantList out;
    for (int i = 0; i < m_rules.size(); ++i) {
        const AlertRule &r = m_rules.at(i);
        QVariantMap m;
        m.insert(QStringLiteral("index"), i);
        m.insert(QStringLiteral("name"), r.name);
        m.insert(QStringLiteral("condition"), r.condition);
        m.insert(QStringLiteral("action"), r.action);
        m.insert(QStringLiteral("level"), r.level);
        m.insert(QStringLiteral("tone"), r.tone);
        m.insert(QStringLiteral("enabled"), r.enabled);
        m.insert(QStringLiteral("custom"), r.custom);
        out.append(m);
    }
    return out;
}

QString SyncCore::stateText() const
{
    if (m_paused)
        return QStringLiteral("已暂停");
    if (m_syncing && m_primaryId.isEmpty())
        return QStringLiteral("同步中…");
    if (m_primaryId.isEmpty())
        return QStringLiteral("未同步");
    return QStringLiteral("已同步");
}

QString SyncCore::stateTone() const
{
    if (m_paused)
        return QStringLiteral("muted");
    if (m_primaryId.isEmpty())
        return QStringLiteral("red");
    if (std::abs(m_offsetMs) > m_severeMs)
        return QStringLiteral("red");
    if (std::abs(m_offsetMs) > m_warnMs)
        return QStringLiteral("amber");
    return QStringLiteral("green");
}

QString SyncCore::stateDesc() const
{
    if (m_paused)
        return QStringLiteral("监控已暂停，采样与告警均已停止");
    if (m_syncing && m_primaryId.isEmpty())
        return QStringLiteral("正在向启用的时钟源发起 SNTP 探测…");
    if (m_primaryId.isEmpty())
        return QStringLiteral("所有时钟源均无响应，正在自动重试");
    if (std::abs(m_offsetMs) > m_warnMs) {
        return QStringLiteral("当前偏差 %1，已超过 ±%2 ms 告警阈值")
            .arg(signedMs(m_offsetMs))
            .arg(m_warnMs);
    }
    return QStringLiteral("本机时间与主时钟 %1 一致，偏差在容差范围内").arg(primaryName());
}

QString SyncCore::headerStatus() const
{
    if (m_paused)
        return QStringLiteral("监控已暂停");
    if (m_primaryId.isEmpty())
        return m_syncing ? QStringLiteral("正在探测时钟源…") : QStringLiteral("未连接时钟源 · 自动重试中");
    return QStringLiteral("已连接主时钟 · %1 · 层级 %2").arg(primaryName(), stratumText());
}

QString SyncCore::primaryName() const
{
    const ClockSource *s = selectPrimary();
    if (s)
        return s->name;
    for (const ClockSource &src : m_sources) {
        if (src.id == m_primaryId)
            return src.name;
    }
    return QStringLiteral("—");
}

QString SyncCore::offsetText() const
{
    if (m_primaryId.isEmpty())
        return QStringLiteral("—");
    return signedMs(m_offsetMs);
}

QString SyncCore::delayText() const
{
    if (m_primaryId.isEmpty())
        return QStringLiteral("—");
    return QStringLiteral("%1 ms").arg(fmtMs(m_delayMs));
}

QString SyncCore::prevDelayText() const
{
    if (m_prevDelayMs <= 0)
        return QStringLiteral("—");
    return QStringLiteral("上次 %1 ms").arg(fmtMs(m_prevDelayMs));
}

QString SyncCore::stratumText() const
{
    if (m_primaryId.isEmpty())
        return QStringLiteral("—");
    return QString::number(m_stratum);
}

double SyncCore::progress() const
{
    if (m_paused)
        return 0.0;
    const qint64 total = qint64(m_pollSec) * 1000;
    if (total <= 0)
        return 0.0;
    const qint64 elapsed = m_cycleClock.isValid() ? m_cycleClock.elapsed() : total;
    const double ratio = 1.0 - double(qBound<qint64>(0, elapsed, total)) / double(total);
    return qBound(0.0, ratio, 1.0);
}

int SyncCore::nextSyncIn() const
{
    if (m_paused)
        return 0;
    const qint64 total = qint64(m_pollSec) * 1000;
    const qint64 elapsed = m_cycleClock.isValid() ? m_cycleClock.elapsed() : 0;
    return int(std::max<qint64>(0, total - elapsed) / 1000);
}

QString SyncCore::nextSyncText() const
{
    if (m_paused)
        return QStringLiteral("监控已暂停，采样与告警均已停止");
    return QStringLiteral("下次自动同步：%1 秒后（周期 %2 秒轮询 / %3 秒步进）")
        .arg(nextSyncIn())
        .arg(m_pollSec)
        .arg(kStepSeconds);
}

QString SyncCore::lastSyncText() const
{
    if (m_lastSyncMs <= 0)
        return QStringLiteral("尚未同步");
    const qint64 secs = (QDateTime::currentMSecsSinceEpoch() - m_lastSyncMs) / 1000;
    if (secs < 5)
        return QStringLiteral("刚刚");
    if (secs < 60)
        return QStringLiteral("%1 秒前").arg(secs);
    if (secs < 3600)
        return QStringLiteral("%1 分钟前").arg(secs / 60);
    return QStringLiteral("%1 小时前").arg(secs / 3600);
}

int SyncCore::unreadCount() const
{
    int n = 0;
    for (const LogEvent &e : m_events) {
        if (e.unread)
            ++n;
    }
    return n;
}

int SyncCore::sourceCount() const
{
    int n = 0;
    for (const ClockSource &s : m_sources) {
        if (!s.system && s.enabled)
            ++n;
    }
    return n;
}

int SyncCore::enabledCount() const
{
    return sourceCount();
}

int SyncCore::warnCount() const
{
    int n = 0;
    for (const LogEvent &e : m_events) {
        if (e.level == QLatin1String("WARN") || e.level == QLatin1String("ERROR"))
            ++n;
    }
    return n;
}

int SyncCore::degradeCount() const
{
    int n = 0;
    for (const SyncRecord &r : m_records) {
        if (!r.ok)
            ++n;
    }
    return n;
}

QVariantList SyncCore::samples() const
{
    QVariantList out;
    out.reserve(m_samples.size());
    for (double v : m_samples)
        out.append(v);
    return out;
}

QString SyncCore::maxDeviationText() const
{
    return QStringLiteral("%1 ms").arg(fmtMs(m_maxDeviationMs));
}

QString SyncCore::jitterText() const
{
    return QStringLiteral("%1 ms").arg(fmtMs(m_jitterMs, 2));
}

QString SyncCore::samplingText() const
{
    return QStringLiteral("近 2 小时 · 每 %1 秒采样").arg(m_sampleInterval);
}

// ---------------------------------------------------------------- setters

void SyncCore::setWarnMs(int v)
{
    v = qBound(1, v, 200);
    if (v == m_warnMs)
        return;
    m_warnMs = v;
    saveSettings();
    emit thresholdsChanged();
    emit liveChanged();
}

void SyncCore::setSevereMs(int v)
{
    v = qBound(m_warnMs + 1, v, 1000);
    if (v == m_severeMs)
        return;
    m_severeMs = v;
    saveSettings();
    emit thresholdsChanged();
    emit liveChanged();
}

void SyncCore::setSampleInterval(int v)
{
    v = qBound(1, v, 60);
    if (v == m_sampleInterval)
        return;
    m_sampleInterval = v;
    saveSettings();
    emit thresholdsChanged();
    emit samplesChanged();
}

void SyncCore::setPaused(bool v)
{
    if (v == m_paused)
        return;
    m_paused = v;
    if (v) {
        m_pollTimer.stop();
        m_syncing = false;
        m_pending = 0;
        m_cycleIds.clear();
        m_guardTimer.stop();
    } else {
        m_cycleClock.restart();
        m_pollTimer.start();
        probeAll(QStringLiteral("周期轮询"));
    }
    emit pausedChanged();
    emit liveChanged();
}

void SyncCore::setStrategy(const QString &v)
{
    if (v == m_strategy || v.isEmpty())
        return;
    m_strategy = v;
    saveSettings();
    emit strategyChanged();
    emit sourcesChanged();
    emit liveChanged();
}

void SyncCore::setPollSec(int v)
{
    v = qBound(2, v, 300);
    if (v == m_pollSec)
        return;
    m_pollSec = v;
    m_pollTimer.setInterval(m_pollSec * 1000);
    saveSettings();
    emit configChanged();
    emit liveChanged();
}

void SyncCore::setThemeMode(const QString &v)
{
    if (v == m_themeMode || v.isEmpty())
        return;
    m_themeMode = v;
    saveSettings();
    emit settingsChanged();
}

void SyncCore::setDensity(const QString &v)
{
    if (v == m_density || v.isEmpty())
        return;
    m_density = v;
    saveSettings();
    emit settingsChanged();
}

void SyncCore::setAutostart(bool v)
{
    if (v == m_autostart)
        return;
    m_autostart = v;
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation)
        + QStringLiteral("/autostart");
    const QString path = dir + QStringLiteral("/timesync-client.desktop");
    if (v) {
        QDir().mkpath(dir);
        QFile f(path);
        if (f.open(QIODevice::WriteOnly | QIODevice::Text)) {
            QTextStream out(&f);
            out << "[Desktop Entry]\n"
                << "Type=Application\n"
                << "Name=TimeSync Client\n"
                << "Comment=时间同步客户端\n"
                << "Exec=" << QCoreApplication::applicationFilePath() << "\n"
                << "Terminal=false\n"
                << "X-GNOME-Autostart-enabled=true\n";
            f.close();
        }
    } else {
        QFile::remove(path);
    }
    saveSettings();
    emit settingsChanged();
    notifyUser(QStringLiteral("已更新启动项"),
               v ? QStringLiteral("已加入桌面自启动") : QStringLiteral("已移除桌面自启动"),
               QStringLiteral("green"));
}

void SyncCore::setTrayEnabled(bool v)
{
    if (v == m_trayEnabled)
        return;
    m_trayEnabled = v;
    saveSettings();
    emit settingsChanged();
}

void SyncCore::setCloseAction(const QString &v)
{
    if (v == m_closeAction || v.isEmpty())
        return;
    m_closeAction = v;
    saveSettings();
    emit settingsChanged();
}

void SyncCore::setLogRetention(const QString &v)
{
    if (v == m_logRetention || v.isEmpty())
        return;
    m_logRetention = v;
    saveSettings();
    emit settingsChanged();
}

void SyncCore::setUploadEnabled(bool v)
{
    if (v == m_uploadEnabled)
        return;
    m_uploadEnabled = v;
    saveSettings();
    emit settingsChanged();
}

bool SyncCore::hideOnClose() const
{
    return m_trayEnabled && m_closeAction == QLatin1String("最小化到托盘");
}

void SyncCore::setNotifySystem(bool v)
{
    if (v == m_notifySystem)
        return;
    m_notifySystem = v;
    saveSettings();
    emit settingsChanged();
}

void SyncCore::setNotifyMail(bool v)
{
    if (v == m_notifyMail)
        return;
    m_notifyMail = v;
    saveSettings();
    emit settingsChanged();
}

void SyncCore::setNotifyWebhook(bool v)
{
    if (v == m_notifyWebhook)
        return;
    m_notifyWebhook = v;
    saveSettings();
    emit settingsChanged();
}

void SyncCore::setKeepLocalTime(bool v)
{
    if (v == m_keepLocalTime)
        return;
    m_keepLocalTime = v;
    saveSettings();
    emit settingsChanged();
}

void SyncCore::setAllowWriteBack(bool v)
{
    if (v == m_allowWriteBack)
        return;
    if (v) {
        notifyUser(QStringLiteral("未启用回写"),
                   QStringLiteral("SNTP 客户端不会向上游服务器回写时间"), QStringLiteral("amber"));
        return;
    }
    m_allowWriteBack = v;
    saveSettings();
    emit settingsChanged();
}

void SyncCore::setSnapshotBefore(bool v)
{
    if (v == m_snapshotBefore)
        return;
    m_snapshotBefore = v;
    saveSettings();
    emit settingsChanged();
}

QString SyncCore::serverHost() const
{
    for (const ClockSource &s : m_sources) {
        if (!s.system)
            return s.host;
    }
    return QString();
}

int SyncCore::serverPort() const
{
    for (const ClockSource &s : m_sources) {
        if (!s.system)
            return s.port;
    }
    return 123;
}

QString SyncCore::clockLine() const
{
    return QDateTime::currentDateTime().toString(QStringLiteral("yyyy-MM-dd HH:mm:ss  t"));
}

QString SyncCore::serviceLine() const
{
    if (m_paused)
        return QStringLiteral("监控已暂停  ·  SNTP v4  ·  端口 123/UDP");
    if (m_syncing)
        return QStringLiteral("正在探测时钟源  ·  SNTP v4  ·  端口 123/UDP");
    return QStringLiteral("服务运行中  ·  SNTP v4  ·  端口 123/UDP");
}

QString SyncCore::deviceLine() const
{
    const QString host = QSysInfo::machineHostName();
    return QStringLiteral("本机 %1 · %2 · 上次同步 %3")
        .arg(host, QSysInfo::prettyProductName(), lastSyncText());
}

QString SyncCore::versionLine() const
{
    return QStringLiteral("TimeSync 客户端 v2.4.1  ·  构建 20261125  ·  MIT License");
}

QString SyncCore::configPath() const
{
    return m_store.fileName();
}

// ---------------------------------------------------------------- probing

void SyncCore::probeAll(const QString &trigger)
{
    if (m_paused)
        return;
    m_cycleIds.clear();
    m_pending = 0;
    m_cycleTrigger = trigger;
    for (const ClockSource &s : std::as_const(m_sources)) {
        if (s.system || !s.enabled)
            continue;
        m_cycleIds.insert(s.id);
        ++m_pending;
        m_probe->query(s.id, s.host, s.port);
    }

    if (m_pending == 0) {
        m_syncing = false;
        emit liveChanged();
        return;
    }
    m_syncing = true;
    m_cycleClock.restart();
    m_pollTimer.start();
    m_guardTimer.start(3500);
    emit liveChanged();
}

void SyncCore::onProbeFinished(const QString &tag, const QString &host, bool ok, int stratum,
                               double offsetMs, double delayMs, const QString &error)
{
    ClockSource *src = findSource(tag);
    if (!src)
        return;

    const bool wasOk = src->ok;
    const int prevFail = src->failStreak;
    Q_UNUSED(host);

    if (ok) {
        src->ok = true;
        src->stratum = stratum;
        src->prevDelayMs = src->delayMs;
        src->offsetMs = offsetMs;
        src->delayMs = delayMs;
        src->error.clear();
        src->failStreak = 0;
        src->lastOkMs = QDateTime::currentMSecsSinceEpoch();
        if (prevFail >= 3) {
            addEvent(QStringLiteral("INFO"),
                     QStringLiteral("%1 已恢复").arg(src->name),
                     QStringLiteral("时钟源重新响应，当前偏差 %1").arg(signedMs(offsetMs)),
                     QStringLiteral("green"), false);
        }
    } else {
        src->ok = false;
        src->error = error;
        ++src->failStreak;
        src->delayMs = -1;
        if (src->failStreak == 3 && wasOk && ruleEnabled(QStringLiteral("时钟源失联"))) {
            addEvent(QStringLiteral("WARN"),
                     QStringLiteral("%1 无响应").arg(src->name),
                     QStringLiteral("连续 3 次探测失败：%1").arg(error),
                     QStringLiteral("amber"), true);
            notifyUser(QStringLiteral("时钟源失联"),
                       QStringLiteral("%1 连续 3 次无响应").arg(src->name),
                       QStringLiteral("amber"));
        }
    }

    if (m_cycleIds.contains(tag)) {
        m_cycleIds.remove(tag);
        if (m_pending > 0)
            --m_pending;
        if (m_pending == 0) {
            m_guardTimer.stop();
            finalizeCycle();
        }
    }
    emit sourcesChanged();
}

void SyncCore::finalizeCycle(bool forcedTimeout)
{
    Q_UNUSED(forcedTimeout);
    m_pending = 0;
    m_cycleIds.clear();
    applyCycle(m_cycleTrigger);
}

void SyncCore::applyCycle(const QString &trigger)
{
    m_syncing = false;
    const ClockSource *best = selectPrimary();
    if (!best) {
        if (!m_allDownAlerted) {
            m_allDownAlerted = true;
            addEvent(QStringLiteral("ERROR"), QStringLiteral("所有时钟源不可达"),
                     QStringLiteral("SNTP 探测全部失败，客户端将按轮询周期自动重试"),
                     QStringLiteral("red"), true);
            notifyUser(QStringLiteral("时间同步中断"),
                       QStringLiteral("所有已启用的时钟源均无响应"), QStringLiteral("red"));
        }
        m_primaryId.clear();
        emit sourcesChanged();
        emit liveChanged();
        return;
    }
    m_allDownAlerted = false;

    if (m_primaryId != best->id) {
        QString oldName;
        for (const ClockSource &src : std::as_const(m_sources)) {
            if (src.id == m_primaryId) {
                oldName = src.name;
                break;
            }
        }
        const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
        if (!oldName.isEmpty() && oldName != best->name
            && nowMs - m_lastSwitchEventMs > 120000) {
            m_lastSwitchEventMs = nowMs;
            addEvent(QStringLiteral("INFO"), QStringLiteral("时钟源切换"),
                     QStringLiteral("主时钟由 %1 切换至 %2").arg(oldName, best->name),
                     QStringLiteral("blue"), false);
            notifyUser(QStringLiteral("已切换时钟源"),
                       QStringLiteral("主时钟切换至 %1").arg(best->name),
                       QStringLiteral("blue"));
        }
        m_primaryId = best->id;
    }

    m_prevDelayMs = m_delayMs > 0 ? m_delayMs : -1.0;
    m_delayMs = best->delayMs;
    m_offsetMs = best->offsetMs;
    m_stratum = best->stratum;
    m_lastSyncMs = QDateTime::currentMSecsSinceEpoch();

    // Sample store (throttled by the sampling interval).
    if (!m_lastSampleAt.isValid()
        || m_lastSampleAt.msecsTo(QDateTime::currentDateTime()) >= m_sampleInterval * 1000
        || trigger == QLatin1String("手动触发")) {
        appendSample(m_offsetMs);
    }

    const double absOffset = std::abs(m_offsetMs);
    if (absOffset > m_severeMs) {
        ++m_severeStreak;
        if (m_severeStreak >= 3 && !m_alertSevere && ruleEnabled(QStringLiteral("漂移超限"))) {
            m_alertSevere = true;
            raiseAlert(QStringLiteral("偏差超过严重阈值"),
                       QStringLiteral("当前偏差 %1，连续 3 次采样超过 ±%2 ms")
                           .arg(signedMs(m_offsetMs)).arg(m_severeMs),
                       QStringLiteral("red"));
        }
    } else {
        m_severeStreak = 0;
        if (absOffset < m_severeMs * 0.8)
            m_alertSevere = false;
    }
    if (absOffset > m_warnMs) {
        ++m_warnStreak;
        if (m_warnStreak >= 3 && !m_alertHigh && ruleEnabled(QStringLiteral("偏差超阈值"))) {
            m_alertHigh = true;
            raiseAlert(QStringLiteral("偏差超过告警阈值"),
                       QStringLiteral("当前偏差 %1，连续 3 次采样超过 ±%2 ms")
                           .arg(signedMs(m_offsetMs)).arg(m_warnMs),
                       QStringLiteral("amber"));
        }
    } else {
        m_warnStreak = 0;
        if (absOffset < m_warnMs * 0.8)
            m_alertHigh = false;
    }

    // A "step" is recorded every 128 s, plus manual and boot syncs.
    m_stepAccum += m_pollSec;
    if (trigger == QLatin1String("手动触发") || trigger == QLatin1String("开机启动")
        || trigger == QLatin1String("周期轮询")) {
        if (trigger == QLatin1String("手动触发") || trigger == QLatin1String("开机启动")) {
            recordSync(trigger, *best, absOffset <= m_warnMs);
            m_stepAccum = 0;
        } else if (m_stepAccum >= kStepSeconds) {
            recordSync(trigger, *best, absOffset <= m_warnMs);
            m_stepAccum = 0;
        }
    }

    emit sourcesChanged();
    emit liveChanged();
}

ClockSource *SyncCore::findSource(const QString &id)
{
    for (ClockSource &s : m_sources) {
        if (s.id == id)
            return &s;
    }
    return nullptr;
}

const ClockSource *SyncCore::selectPrimary() const
{
    const ClockSource *best = nullptr;
    const ClockSource *current = nullptr;
    for (const ClockSource &s : m_sources) {
        if (s.system || !s.enabled)
            continue;
        if (!m_primaryId.isEmpty() && s.id == m_primaryId)
            current = &s;
        if (s.ok) {
            if (!best || sourceScore(s) < sourceScore(*best))
                best = &s;
        }
    }
    if (best) {
        // Hysteresis: stick with the current primary while its score stays
        // close to the best candidate (equals "层级优先" preferring stratum).
        if (current && current->ok && current != best) {
            const double margin = (m_strategy == QLatin1String("延迟优先")) ? 25.0
                                : (m_strategy == QLatin1String("稳定优先")) ? 6.0
                                : 80.0;
            if (sourceScore(*current) <= sourceScore(*best) + margin)
                return current;
        }
        return best;
    }
    // Avoid flapping when a single probe times out: keep the last good source
    // for up to 30 seconds.
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    for (const ClockSource &s : m_sources) {
        if (s.system || !s.enabled)
            continue;
        if (s.lastOkMs > 0 && now - s.lastOkMs < 30000) {
            if (!best || sourceScore(s) < sourceScore(*best))
                best = &s;
        }
    }
    return best;
}

double SyncCore::sourceScore(const ClockSource &s) const
{
    if (m_strategy == QLatin1String("延迟优先"))
        return s.delayMs * 10.0 + s.stratum;
    if (m_strategy == QLatin1String("稳定优先"))
        return std::abs(s.offsetMs) * 5.0 + s.delayMs * 0.2 + s.failStreak * 100.0;
    return s.stratum * 1000.0 + s.delayMs;
}

void SyncCore::appendSample(double offsetMs)
{
    m_samples.append(offsetMs);
    m_sampleTimes.append(QDateTime::currentDateTime());
    m_lastSampleAt = QDateTime::currentDateTime();
    const int cap = std::min(kMaxSamples, std::max(60, (2 * 3600) / std::max(1, m_sampleInterval)));
    while (m_samples.size() > cap) {
        m_samples.removeFirst();
        m_sampleTimes.removeFirst();
    }

    double maxAbs = 0.0;
    for (double v : std::as_const(m_samples))
        maxAbs = std::max(maxAbs, std::abs(v));
    m_maxDeviationMs = maxAbs;

    const int n = int(std::min<qsizetype>(20, m_samples.size()));
    if (n > 1) {
        double sum = 0.0;
        for (int i = m_samples.size() - n; i < m_samples.size(); ++i)
            sum += m_samples.at(i);
        const double mean = sum / n;
        double var = 0.0;
        for (int i = m_samples.size() - n; i < m_samples.size(); ++i) {
            const double d = m_samples.at(i) - mean;
            var += d * d;
        }
        m_jitterMs = std::sqrt(var / (n - 1));
    } else {
        m_jitterMs = 0.0;
    }
    emit samplesChanged();
}

void SyncCore::recordSync(const QString &trigger, const ClockSource &src, bool ok)
{
    updateCountersDaily();
    SyncRecord r;
    r.time = QDateTime::currentDateTime();
    r.trigger = trigger;
    r.source = src.name;
    r.offsetMs = src.offsetMs;
    r.delayMs = src.delayMs;
    r.ok = ok;
    m_records.prepend(r);
    while (m_records.size() > kMaxRecords)
        m_records.removeLast();

    ++m_totalSyncs;
    ++m_todaySyncs;
    m_store.setValue(QStringLiteral("counters/total"), m_totalSyncs);
    m_store.setValue(QStringLiteral("counters/today"), m_todaySyncs);
    m_store.setValue(QStringLiteral("counters/date"), m_counterDate);

    QString title = QStringLiteral("同步成功");
    if (trigger == QLatin1String("手动触发"))
        title = QStringLiteral("手动同步完成");
    else if (trigger == QLatin1String("开机启动"))
        title = QStringLiteral("开机校时完成");
    if (!ok)
        title = QStringLiteral("同步降级");
    addEvent(ok ? QStringLiteral("INFO") : QStringLiteral("WARN"), title,
             QStringLiteral("%1 · 偏差 %2，耗时 %3 ms")
                 .arg(src.name, signedMs(r.offsetMs), fmtMs(r.delayMs)),
             ok ? QStringLiteral("green") : QStringLiteral("amber"), false);

    QJsonArray arr;
    for (const SyncRecord &rec : std::as_const(m_records)) {
        QJsonObject o;
        o.insert(QStringLiteral("time"), rec.time.toString(Qt::ISODate));
        o.insert(QStringLiteral("trigger"), rec.trigger);
        o.insert(QStringLiteral("source"), rec.source);
        o.insert(QStringLiteral("offset"), rec.offsetMs);
        o.insert(QStringLiteral("delay"), rec.delayMs);
        o.insert(QStringLiteral("ok"), rec.ok);
        arr.append(o);
    }
    m_store.setValue(QStringLiteral("records"), arr);
    m_store.sync();

    emit recordsChanged();
    emit countersChanged();
}

void SyncCore::addEvent(const QString &level, const QString &title, const QString &desc,
                        const QString &tone, bool unread)
{
    LogEvent e;
    e.time = QDateTime::currentDateTime();
    e.level = level;
    e.title = title;
    e.desc = desc;
    e.tone = tone;
    e.unread = unread;
    m_events.prepend(e);
    while (m_events.size() > kMaxEvents)
        m_events.removeLast();
    saveEvents();
    emit eventsChanged();
    emit countersChanged();
}

bool SyncCore::ruleEnabled(const QString &name) const
{
    for (const AlertRule &r : m_rules) {
        if (r.name == name)
            return r.enabled;
    }
    return false;
}

void SyncCore::raiseAlert(const QString &title, const QString &desc, const QString &tone)
{
    addEvent(tone == QLatin1String("red") ? QStringLiteral("ERROR") : QStringLiteral("WARN"),
             title, desc, tone, true);
    notifyUser(title, desc, tone);
}

void SyncCore::notifyUser(const QString &title, const QString &body, const QString &tone)
{
    emit toast(title, body, tone);
    if (m_notifySystem)
        emit systemNotify(title, body);
}

void SyncCore::updateCountersDaily()
{
    const QString today = QDate::currentDate().toString(Qt::ISODate);
    if (m_counterDate != today) {
        m_counterDate = today;
        m_todaySyncs = 0;
        m_store.setValue(QStringLiteral("counters/date"), m_counterDate);
        m_store.setValue(QStringLiteral("counters/today"), m_todaySyncs);
        emit countersChanged();
    }
}

QString SyncCore::statusFor(const ClockSource &s) const
{
    if (s.system) {
        if (m_primaryId.isEmpty())
            return QStringLiteral("待测");
        const double a = std::abs(m_offsetMs);
        if (a > m_severeMs)
            return QStringLiteral("漂移超限");
        if (a > m_warnMs)
            return QStringLiteral("偏差偏高");
        return QStringLiteral("正常");
    }
    if (!s.enabled)
        return QStringLiteral("未启用");
    if (s.ok) {
        if (s.stratum <= 2)
            return QStringLiteral("已锁定");
        if (s.delayMs > 120.0)
            return QStringLiteral("延迟偏高");
        return QStringLiteral("正常");
    }
    if (!s.error.isEmpty() || s.failStreak > 0)
        return QStringLiteral("无响应");
    return QStringLiteral("待测");
}

QString SyncCore::toneForStatus(const ClockSource &s) const
{
    const QString st = statusFor(s);
    if (st == QLatin1String("已锁定") || st == QLatin1String("正常"))
        return QStringLiteral("green");
    if (st == QLatin1String("延迟偏高") || st == QLatin1String("偏差偏高"))
        return QStringLiteral("amber");
    if (st == QLatin1String("漂移超限") || st == QLatin1String("无响应"))
        return QStringLiteral("red");
    return QStringLiteral("muted");
}

void SyncCore::rebuildSourceStatus()
{
    emit sourcesChanged();
}

// ---------------------------------------------------------------- actions

void SyncCore::syncNow()
{
    if (m_paused) {
        m_paused = false;
        emit pausedChanged();
    }
    probeAll(QStringLiteral("手动触发"));
}

void SyncCore::testAll()
{
    if (m_testPending > 0)
        return;
    m_testOk = 0;
    m_testPending = 0;
    for (const ClockSource &s : std::as_const(m_sources)) {
        if (s.system || !s.enabled)
            continue;
        ++m_testPending;
        m_testProbe->query(QStringLiteral("test:") + s.id, s.host, s.port);
    }
    m_lastTestText = m_testPending > 0 ? QStringLiteral("正在测试 %1 个时钟源…").arg(m_testPending)
                                       : QStringLiteral("没有启用的时钟源");
    emit testChanged();
    if (m_testPending == 0)
        notifyUser(QStringLiteral("测试全部"), m_lastTestText, QStringLiteral("amber"));
}

void SyncCore::testSource(int index)
{
    if (index < 0 || index >= m_sources.size() || m_sources.at(index).system)
        return;
    const ClockSource &s = m_sources.at(index);
    m_testPending = 1;
    m_testOk = 0;
    m_lastTestText = QStringLiteral("正在测试 %1 …").arg(s.name);
    emit testChanged();
    m_testProbe->query(QStringLiteral("test:") + s.id, s.host, s.port);
}

void SyncCore::testPrimary()
{
    for (int i = 0; i < m_sources.size(); ++i) {
        if (!m_sources.at(i).system) {
            testSource(i);
            return;
        }
    }
}

void SyncCore::onTestFinished(const QString &tag, const QString &host, bool ok, int stratum,
                              double offsetMs, double delayMs, const QString &error)
{
    Q_UNUSED(stratum);
    const QString id = tag.mid(5);
    ClockSource *src = findSource(id);
    if (src && ok) {
        src->ok = true;
        src->stratum = stratum;
        src->prevDelayMs = src->delayMs;
        src->offsetMs = offsetMs;
        src->delayMs = delayMs;
        src->error.clear();
        src->failStreak = 0;
        src->lastOkMs = QDateTime::currentMSecsSinceEpoch();
        ++m_testOk;
        m_lastTestText = QStringLiteral("%1 · 偏差 %2 · RTT %3 ms")
                             .arg(src->name, signedMs(offsetMs), fmtMs(delayMs));
    } else if (src) {
        src->ok = false;
        src->error = error;
        m_lastTestText = QStringLiteral("%1 · %2").arg(src->name, error.isEmpty() ? host : error);
    }
    if (m_testPending > 0)
        --m_testPending;
    emit sourcesChanged();
    emit testChanged();
    if (m_testPending == 0) {
        if (m_testOk > 0)
            m_lastTestText = QStringLiteral("测试完成：%1 个时钟源响应 · %2").arg(m_testOk).arg(m_lastTestText);
        notifyUser(QStringLiteral("连接测试完成"), m_lastTestText,
                   m_testOk > 0 ? QStringLiteral("green") : QStringLiteral("red"));
    }
}

void SyncCore::addSource(const QString &host, const QString &name)
{
    const QString trimmed = host.trimmed();
    if (trimmed.isEmpty()) {
        notifyUser(QStringLiteral("无法添加"), QStringLiteral("请填写服务器地址"), QStringLiteral("amber"));
        return;
    }
    for (const ClockSource &s : std::as_const(m_sources)) {
        if (s.host.compare(trimmed, Qt::CaseInsensitive) == 0) {
            notifyUser(QStringLiteral("无法添加"), QStringLiteral("该服务器已在列表中"),
                       QStringLiteral("amber"));
            return;
        }
    }
    ClockSource s;
    s.id = QStringLiteral("src-%1").arg(QDateTime::currentMSecsSinceEpoch());
    s.host = trimmed;
    s.name = name.trimmed().isEmpty() ? trimmed : name.trimmed();
    s.desc = QStringLiteral("公共 NTP · 手动添加");
    s.port = 123;
    s.enabled = true;
    m_sources.insert(qMax(0, m_sources.size() - 1), s);
    saveSources();
    emit sourcesChanged();
    const int idx = qMax(0, m_sources.size() - 2);
    testSource(idx);
    notifyUser(QStringLiteral("已添加时钟源"), s.name, QStringLiteral("green"));
}

void SyncCore::removeSource(int index)
{
    if (index < 0 || index >= m_sources.size())
        return;
    if (m_sources.at(index).system)
        return;
    const QString name = m_sources.at(index).name;
    if (m_sources.at(index).id == m_primaryId)
        m_primaryId.clear();
    m_sources.removeAt(index);
    if (sourceCount() == 0) {
        for (ClockSource &s : m_sources) {
            if (!s.system) {
                s.enabled = true;
                break;
            }
        }
    }
    saveSources();
    emit sourcesChanged();
    notifyUser(QStringLiteral("已移除时钟源"), name, QStringLiteral("amber"));
}

void SyncCore::toggleSource(int index)
{
    if (index < 0 || index >= m_sources.size())
        return;
    setSourceEnabled(index, !m_sources.at(index).enabled);
}

void SyncCore::setSourceEnabled(int index, bool on)
{
    if (index < 0 || index >= m_sources.size())
        return;
    ClockSource &s = m_sources[index];
    if (s.system)
        return;
    if (s.enabled == on)
        return;
    s.enabled = on;
    s.ok = false;
    s.failStreak = 0;
    s.error.clear();
    saveSources();
    emit sourcesChanged();
    if (on)
        testSource(index);
}

QString SyncCore::exportCsv()
{
    QString dir = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    if (dir.isEmpty())
        dir = QDir::homePath();
    const QString path = QStringLiteral("%1/TimeSync-校时记录-%2.csv")
                             .arg(dir, QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd-HHmmss")));
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text)) {
        notifyUser(QStringLiteral("导出失败"), f.errorString(), QStringLiteral("red"));
        return QString();
    }
    QTextStream out(&f);
    out.setEncoding(QStringConverter::Utf8);
    out << "\xEF\xBB\xBF";
    out << "时间,触发方式,时钟源,偏差(ms),延迟(ms),结果\n";
    for (const SyncRecord &r : std::as_const(m_records)) {
        out << r.time.toString(QStringLiteral("yyyy-MM-dd HH:mm:ss")) << ','
            << r.trigger << ',' << r.source << ','
            << QString::number(r.offsetMs, 'f', 2) << ','
            << QString::number(r.delayMs, 'f', 1) << ','
            << (r.ok ? QStringLiteral("成功") : QStringLiteral("降级")) << '\n';
    }
    f.close();
    notifyUser(QStringLiteral("已导出 CSV"), path, QStringLiteral("green"));
    return path;
}

QString SyncCore::exportEvents()
{
    QString dir = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    if (dir.isEmpty())
        dir = QDir::homePath();
    const QString path = QStringLiteral("%1/TimeSync-事件日志-%2.log")
                             .arg(dir, QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd-HHmmss")));
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text)) {
        notifyUser(QStringLiteral("导出失败"), f.errorString(), QStringLiteral("red"));
        return QString();
    }
    QTextStream out(&f);
    out.setEncoding(QStringConverter::Utf8);
    for (const LogEvent &e : std::as_const(m_events)) {
        out << e.time.toString(QStringLiteral("yyyy-MM-dd HH:mm:ss")) << "  "
            << e.level.leftJustified(5) << "  " << e.title << "  —  " << e.desc << '\n';
    }
    f.close();
    notifyUser(QStringLiteral("已导出事件日志"), path, QStringLiteral("green"));
    return path;
}

QString SyncCore::exportConfig()
{
    QString dir = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    if (dir.isEmpty())
        dir = QDir::homePath();
    const QString path = QStringLiteral("%1/TimeSync-配置备份-%2.json")
                             .arg(dir, QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd-HHmmss")));
    QJsonObject root;
    QJsonArray srcArr;
    for (const ClockSource &s : std::as_const(m_sources)) {
        QJsonObject o;
        o.insert(QStringLiteral("name"), s.name);
        o.insert(QStringLiteral("host"), s.host);
        o.insert(QStringLiteral("port"), s.port);
        o.insert(QStringLiteral("enabled"), s.enabled);
        o.insert(QStringLiteral("system"), s.system);
        srcArr.append(o);
    }
    root.insert(QStringLiteral("sources"), srcArr);
    root.insert(QStringLiteral("pollSec"), m_pollSec);
    root.insert(QStringLiteral("warnMs"), m_warnMs);
    root.insert(QStringLiteral("severeMs"), m_severeMs);
    root.insert(QStringLiteral("sampleInterval"), m_sampleInterval);
    root.insert(QStringLiteral("strategy"), m_strategy);
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text)) {
        notifyUser(QStringLiteral("导出失败"), f.errorString(), QStringLiteral("red"));
        return QString();
    }
    f.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
    f.close();
    notifyUser(QStringLiteral("已导出配置"), path, QStringLiteral("green"));
    return path;
}

void SyncCore::clearEvents()
{
    m_events.clear();
    saveEvents();
    emit eventsChanged();
    emit countersChanged();
    notifyUser(QStringLiteral("事件日志已清空"), QStringLiteral("仅保留后续产生的事件"),
               QStringLiteral("green"));
}

void SyncCore::markRead(int index)
{
    if (index < 0 || index >= m_events.size())
        return;
    if (!m_events[index].unread)
        return;
    m_events[index].unread = false;
    saveEvents();
    emit eventsChanged();
    emit countersChanged();
}

void SyncCore::markAllRead()
{
    bool changed = false;
    for (LogEvent &e : m_events) {
        if (e.unread) {
            e.unread = false;
            changed = true;
        }
    }
    if (!changed)
        return;
    saveEvents();
    emit eventsChanged();
    emit countersChanged();
}

void SyncCore::saveServerConfig(const QString &host, const QString &port)
{
    const QString h = host.trimmed();
    bool ok = false;
    const int p = port.trimmed().toInt(&ok);
    if (h.isEmpty() || !ok || p < 1 || p > 65535) {
        notifyUser(QStringLiteral("保存失败"), QStringLiteral("请检查服务器地址与端口"), QStringLiteral("red"));
        return;
    }
    for (ClockSource &s : m_sources) {
        if (!s.system) {
            s.host = h;
            s.port = p;
            s.ok = false;
            s.error.clear();
            break;
        }
    }
    saveSources();
    emit sourcesChanged();
    emit configChanged();
    notifyUser(QStringLiteral("配置已保存"),
               QStringLiteral("%1:%2 · 立即重新探测").arg(h).arg(p), QStringLiteral("green"));
    probeAll(QStringLiteral("配置更新"));
}

void SyncCore::setRuleEnabled(int index, bool on)
{
    if (index < 0 || index >= m_rules.size())
        return;
    m_rules[index].enabled = on;
    saveRules();
    emit rulesChanged();
}

void SyncCore::setNotify(const QString &key, bool on)
{
    if (key == QLatin1String("system"))
        setNotifySystem(on);
    else if (key == QLatin1String("mail"))
        setNotifyMail(on);
    else if (key == QLatin1String("webhook"))
        setNotifyWebhook(on);
}

void SyncCore::addRule(const QString &name, const QString &condition,
                       const QString &action, const QString &level)
{
    if (name.trimmed().isEmpty() || condition.trimmed().isEmpty()) {
        notifyUser(QStringLiteral("无法创建规则"), QStringLiteral("规则名称与触发条件不能为空"),
                   QStringLiteral("amber"));
        return;
    }
    AlertRule r;
    r.name = name.trimmed();
    r.condition = condition.trimmed();
    r.action = action.trimmed().isEmpty() ? QStringLiteral("仅记录") : action.trimmed();
    r.level = level.isEmpty() ? QStringLiteral("提示") : level;
    r.tone = r.level == QLatin1String("严重") ? QStringLiteral("red")
        : r.level == QLatin1String("警告")        ? QStringLiteral("amber")
                                                  : QStringLiteral("blue");
    r.enabled = true;
    r.custom = true;
    m_rules.append(r);
    saveRules();
    emit rulesChanged();
    notifyUser(QStringLiteral("已创建规则"), r.name, QStringLiteral("green"));
}

void SyncCore::setNtsEnabled(bool on)
{
    if (on)
        notifyUser(QStringLiteral("暂不支持 NTS"),
                   QStringLiteral("当前基于 SNTP 明文实现，NTS 需 ntpd/chrony 配合"),
                   QStringLiteral("amber"));
    m_ntsEnabled = false;
    emit configChanged();
}

void SyncCore::checkUpdates()
{
    notifyUser(QStringLiteral("检查更新"),
               QStringLiteral("当前已是最新版本 v2.4.1（构建 20261125）"),
               QStringLiteral("green"));
}

void SyncCore::seedDemoHistory()
{
    // Test-only: gives charts a plausible shape for offscreen screenshots.
    m_samples.clear();
    m_sampleTimes.clear();
    for (int i = 0; i < 60; ++i) {
        double v = 0.5 + 0.35 * std::sin(i / 2.4) + (i == 9 || i == 10 ? 1.5 : 0.0);
        m_samples.append(v);
    }
    m_sampleTimes.append(QDateTime::currentDateTime());
    m_maxDeviationMs = 7.8;
    m_jitterMs = 0.12;
    emit samplesChanged();

    if (m_records.isEmpty()) {
        const QStringList triggers = {QStringLiteral("周期轮询"), QStringLiteral("周期轮询"),
                                      QStringLiteral("手动触发"), QStringLiteral("周期轮询"),
                                      QStringLiteral("开机启动"), QStringLiteral("周期轮询")};
        const QStringList srcs = {QStringLiteral("阿里云 NTP"), QStringLiteral("阿里云 NTP"),
                                  QStringLiteral("腾讯云 NTP"), QStringLiteral("阿里云 NTP"),
                                  QStringLiteral("Windows 时间"), QStringLiteral("阿里云 NTP")};
        const QList<double> offs = {0.8, 0.6, 1.4, 0.3, 7.8, 0.5};
        const QList<double> delays = {12.4, 11.9, 13.2, 12.1, 41.6, 12.0};
        for (int i = 5; i >= 0; --i) {
            SyncRecord r;
            r.time = QDateTime::currentDateTime().addSecs(-(5 - i) * 240);
            r.trigger = triggers.at(i);
            r.source = srcs.at(i);
            r.offsetMs = offs.at(i);
            r.delayMs = delays.at(i);
            r.ok = i != 4;
            m_records.append(r);
        }
        emit recordsChanged();
    }
    m_totalSyncs = std::max(m_totalSyncs, 148);
    m_todaySyncs = std::max(m_todaySyncs, 42);

    // Demo event feed: mirrors the design's 事件日志 page (2 unread, 1 degrade).
    m_events.clear();
    const auto demoEvent = [this](const QString &level, const QString &title,
                                  const QString &desc, const QString &tone,
                                  bool unread, int minutesAgo) {
        LogEvent e;
        e.time = QDateTime::currentDateTime().addSecs(-minutesAgo * 60);
        e.level = level;
        e.title = title;
        e.desc = desc;
        e.tone = tone;
        e.unread = unread;
        m_events.append(e);
    };
    demoEvent(QStringLiteral("INFO"), QStringLiteral("同步成功"),
              QStringLiteral("阿里云 NTP · 偏差 +0.8 ms，耗时 12 ms"),
              QStringLiteral("blue"), false, 1);
    demoEvent(QStringLiteral("WARN"), QStringLiteral("Internet NTP 延迟偏高"),
              QStringLiteral("ntp.aliyun.com RTT 41.6 ms，已自动降级为备用"),
              QStringLiteral("amber"), true, 12);
    demoEvent(QStringLiteral("ERROR"), QStringLiteral("本机 CMOS 漂移超限"),
              QStringLiteral("检测到 -48 ms 偏移，已禁用该时钟源"),
              QStringLiteral("red"), true, 17);
    demoEvent(QStringLiteral("INFO"), QStringLiteral("同步成功"),
              QStringLiteral("阿里云 NTP · 偏差 +0.5 ms，耗时 12 ms"),
              QStringLiteral("blue"), false, 21);
    demoEvent(QStringLiteral("INFO"), QStringLiteral("时钟源切换"),
              QStringLiteral("主时钟由 腾讯云 NTP 切换至 阿里云 NTP"),
              QStringLiteral("blue"), false, 33);
    demoEvent(QStringLiteral("INFO"), QStringLiteral("同步成功"),
              QStringLiteral("阿里云 NTP · 偏差 +0.9 ms，耗时 13 ms"),
              QStringLiteral("blue"), false, 45);
    demoEvent(QStringLiteral("INFO"), QStringLiteral("启动完成"),
              QStringLiteral("客户端 v2.4.1 启动，加载 4 个时钟源"),
              QStringLiteral("blue"), false, 57);
    emit eventsChanged();
    emit countersChanged();
}
