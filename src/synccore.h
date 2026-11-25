#pragma once

#include <QDateTime>
#include <QElapsedTimer>
#include <QObject>
#include <QSet>
#include <QSettings>
#include <QTimer>
#include <QVariantList>
#include <QVector>

class NtpProbe;

struct ClockSource {
    QString id;
    QString name;
    QString desc;
    QString host;
    QString proto = QStringLiteral("NTPv4");
    int port = 123;
    bool enabled = true;
    bool system = false;
    bool ok = false;
    int stratum = 0;
    double offsetMs = 0.0;
    double delayMs = -1.0;
    double prevDelayMs = -1.0;
    QString error;
    int failStreak = 0;
    qint64 lastOkMs = 0;
};

struct SyncRecord {
    QDateTime time;
    QString trigger;
    QString source;
    double offsetMs = 0.0;
    double delayMs = 0.0;
    bool ok = true;
};

struct LogEvent {
    QDateTime time;
    QString level;
    QString title;
    QString desc;
    QString tone;
    bool unread = false;
};

struct AlertRule {
    QString name;
    QString condition;
    QString action;
    QString level;
    QString tone;
    bool enabled = true;
    bool custom = false;
};

class SyncCore : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QVariantList sources READ sources NOTIFY sourcesChanged)
    Q_PROPERTY(QVariantList overview READ overview NOTIFY sourcesChanged)
    Q_PROPERTY(QVariantList events READ events NOTIFY eventsChanged)
    Q_PROPERTY(QVariantList records READ records NOTIFY recordsChanged)
    Q_PROPERTY(QVariantList rules READ rules NOTIFY rulesChanged)

    Q_PROPERTY(QString stateText READ stateText NOTIFY liveChanged)
    Q_PROPERTY(QString stateTone READ stateTone NOTIFY liveChanged)
    Q_PROPERTY(QString stateDesc READ stateDesc NOTIFY liveChanged)
    Q_PROPERTY(QString headerStatus READ headerStatus NOTIFY liveChanged)
    Q_PROPERTY(QString primaryName READ primaryName NOTIFY liveChanged)
    Q_PROPERTY(QString offsetText READ offsetText NOTIFY liveChanged)
    Q_PROPERTY(QString delayText READ delayText NOTIFY liveChanged)
    Q_PROPERTY(QString prevDelayText READ prevDelayText NOTIFY liveChanged)
    Q_PROPERTY(QString stratumText READ stratumText NOTIFY liveChanged)
    Q_PROPERTY(double offsetMs READ offsetMs NOTIFY liveChanged)
    Q_PROPERTY(double delayMs READ delayMs NOTIFY liveChanged)
    Q_PROPERTY(double progress READ progress NOTIFY liveChanged)
    Q_PROPERTY(int nextSyncIn READ nextSyncIn NOTIFY liveChanged)
    Q_PROPERTY(QString nextSyncText READ nextSyncText NOTIFY liveChanged)
    Q_PROPERTY(QString lastSyncText READ lastSyncText NOTIFY liveChanged)

    Q_PROPERTY(int totalSyncs READ totalSyncs NOTIFY countersChanged)
    Q_PROPERTY(int todaySyncs READ todaySyncs NOTIFY countersChanged)
    Q_PROPERTY(int unreadCount READ unreadCount NOTIFY eventsChanged)
    Q_PROPERTY(int sourceCount READ sourceCount NOTIFY sourcesChanged)
    Q_PROPERTY(int enabledCount READ enabledCount NOTIFY sourcesChanged)
    Q_PROPERTY(int warnCount READ warnCount NOTIFY eventsChanged)
    Q_PROPERTY(int degradeCount READ degradeCount NOTIFY recordsChanged)
    Q_PROPERTY(int successCount READ successCount NOTIFY countersChanged)
    Q_PROPERTY(int eventCount READ eventCount NOTIFY eventsChanged)

    Q_PROPERTY(QVariantList samples READ samples NOTIFY samplesChanged)
    Q_PROPERTY(int sampleCount READ sampleCount NOTIFY samplesChanged)
    Q_PROPERTY(QString maxDeviationText READ maxDeviationText NOTIFY samplesChanged)
    Q_PROPERTY(QString jitterText READ jitterText NOTIFY samplesChanged)
    Q_PROPERTY(double maxDeviationMs READ maxDeviationMs NOTIFY samplesChanged)
    Q_PROPERTY(QString samplingText READ samplingText NOTIFY samplesChanged)

    Q_PROPERTY(int warnMs READ warnMs WRITE setWarnMs NOTIFY thresholdsChanged)
    Q_PROPERTY(int severeMs READ severeMs WRITE setSevereMs NOTIFY thresholdsChanged)
    Q_PROPERTY(int sampleInterval READ sampleInterval WRITE setSampleInterval NOTIFY thresholdsChanged)
    Q_PROPERTY(bool paused READ paused WRITE setPaused NOTIFY pausedChanged)
    Q_PROPERTY(bool syncing READ syncing NOTIFY liveChanged)
    Q_PROPERTY(QString strategy READ strategy WRITE setStrategy NOTIFY strategyChanged)
    Q_PROPERTY(QString lastTestText READ lastTestText NOTIFY testChanged)
    Q_PROPERTY(bool testing READ testing NOTIFY testChanged)

    Q_PROPERTY(QString serverHost READ serverHost NOTIFY configChanged)
    Q_PROPERTY(int serverPort READ serverPort NOTIFY configChanged)
    Q_PROPERTY(int pollSec READ pollSec WRITE setPollSec NOTIFY configChanged)
    Q_PROPERTY(bool ntsEnabled READ ntsEnabled NOTIFY configChanged)

    Q_PROPERTY(QString themeMode READ themeMode WRITE setThemeMode NOTIFY settingsChanged)
    Q_PROPERTY(bool systemDark READ systemDark CONSTANT)
    Q_PROPERTY(QString density READ density WRITE setDensity NOTIFY settingsChanged)
    Q_PROPERTY(bool autostart READ autostart WRITE setAutostart NOTIFY settingsChanged)
    Q_PROPERTY(bool trayEnabled READ trayEnabled WRITE setTrayEnabled NOTIFY settingsChanged)
    Q_PROPERTY(QString closeAction READ closeAction WRITE setCloseAction NOTIFY settingsChanged)
    Q_PROPERTY(QString logRetention READ logRetention WRITE setLogRetention NOTIFY settingsChanged)
    Q_PROPERTY(bool uploadEnabled READ uploadEnabled WRITE setUploadEnabled NOTIFY settingsChanged)
    Q_PROPERTY(bool hideOnClose READ hideOnClose NOTIFY settingsChanged)
    Q_PROPERTY(bool notifySystem READ notifySystem WRITE setNotifySystem NOTIFY settingsChanged)
    Q_PROPERTY(bool notifyMail READ notifyMail WRITE setNotifyMail NOTIFY settingsChanged)
    Q_PROPERTY(bool notifyWebhook READ notifyWebhook WRITE setNotifyWebhook NOTIFY settingsChanged)
    Q_PROPERTY(bool keepLocalTime READ keepLocalTime WRITE setKeepLocalTime NOTIFY settingsChanged)
    Q_PROPERTY(bool allowWriteBack READ allowWriteBack WRITE setAllowWriteBack NOTIFY settingsChanged)
    Q_PROPERTY(bool snapshotBefore READ snapshotBefore WRITE setSnapshotBefore NOTIFY settingsChanged)

    Q_PROPERTY(QString clockLine READ clockLine NOTIFY clockChanged)
    Q_PROPERTY(QString serviceLine READ serviceLine NOTIFY liveChanged)
    Q_PROPERTY(QString deviceLine READ deviceLine NOTIFY liveChanged)
    Q_PROPERTY(QString versionLine READ versionLine CONSTANT)
    Q_PROPERTY(QString configPath READ configPath NOTIFY settingsChanged)

public:
    explicit SyncCore(QObject *parent = nullptr);

    QVariantList sources() const;
    QVariantList overview() const;
    QVariantList events() const;
    QVariantList records() const;
    QVariantList rules() const;

    QString stateText() const;
    QString stateTone() const;
    QString stateDesc() const;
    QString headerStatus() const;
    QString primaryName() const;
    QString offsetText() const;
    QString delayText() const;
    QString prevDelayText() const;
    QString stratumText() const;
    double offsetMs() const { return m_offsetMs; }
    double delayMs() const { return m_delayMs; }
    double progress() const;
    int nextSyncIn() const;
    QString nextSyncText() const;
    QString lastSyncText() const;

    int totalSyncs() const { return m_totalSyncs; }
    int todaySyncs() const { return m_todaySyncs; }
    int unreadCount() const;
    int sourceCount() const;
    int enabledCount() const;
    int warnCount() const;
    int degradeCount() const;
    int successCount() const { return m_totalSyncs; }
    int eventCount() const { return m_events.size(); }

    QVariantList samples() const;
    int sampleCount() const { return m_samples.size(); }
    QString maxDeviationText() const;
    QString jitterText() const;
    double maxDeviationMs() const { return m_maxDeviationMs; }
    QString samplingText() const;

    int warnMs() const { return m_warnMs; }
    void setWarnMs(int v);
    int severeMs() const { return m_severeMs; }
    void setSevereMs(int v);
    int sampleInterval() const { return m_sampleInterval; }
    void setSampleInterval(int v);
    bool paused() const { return m_paused; }
    bool syncing() const { return m_syncing; }
    void setPaused(bool v);
    QString strategy() const { return m_strategy; }
    void setStrategy(const QString &v);
    QString lastTestText() const { return m_lastTestText; }
    bool testing() const { return m_testPending > 0; }

    QString serverHost() const;
    int serverPort() const;
    int pollSec() const { return m_pollSec; }
    void setPollSec(int v);
    bool ntsEnabled() const { return m_ntsEnabled; }

    QString themeMode() const { return m_themeMode; }
    void setThemeMode(const QString &v);
    bool systemDark() const { return m_systemDark; }
    QString density() const { return m_density; }
    void setDensity(const QString &v);
    bool autostart() const { return m_autostart; }
    void setAutostart(bool v);
    bool trayEnabled() const { return m_trayEnabled; }
    void setTrayEnabled(bool v);
    QString closeAction() const { return m_closeAction; }
    void setCloseAction(const QString &v);
    QString logRetention() const { return m_logRetention; }
    void setLogRetention(const QString &v);
    bool uploadEnabled() const { return m_uploadEnabled; }
    void setUploadEnabled(bool v);
    bool hideOnClose() const;
    bool notifySystem() const { return m_notifySystem; }
    void setNotifySystem(bool v);
    bool notifyMail() const { return m_notifyMail; }
    void setNotifyMail(bool v);
    bool notifyWebhook() const { return m_notifyWebhook; }
    void setNotifyWebhook(bool v);
    bool keepLocalTime() const { return m_keepLocalTime; }
    void setKeepLocalTime(bool v);
    bool allowWriteBack() const { return m_allowWriteBack; }
    void setAllowWriteBack(bool v);
    bool snapshotBefore() const { return m_snapshotBefore; }
    void setSnapshotBefore(bool v);

    QString clockLine() const;
    QString serviceLine() const;
    QString deviceLine() const;
    QString versionLine() const;
    QString configPath() const;

    Q_INVOKABLE void syncNow();
    Q_INVOKABLE void testAll();
    Q_INVOKABLE void testSource(int index);
    Q_INVOKABLE void testPrimary();
    Q_INVOKABLE void addSource(const QString &host, const QString &name);
    Q_INVOKABLE void removeSource(int index);
    Q_INVOKABLE void toggleSource(int index);
    Q_INVOKABLE void setSourceEnabled(int index, bool on);
    Q_INVOKABLE QString exportCsv();
    Q_INVOKABLE QString exportEvents();
    Q_INVOKABLE QString exportConfig();
    Q_INVOKABLE void clearEvents();
    Q_INVOKABLE void markRead(int index);
    Q_INVOKABLE void markAllRead();
    Q_INVOKABLE void saveServerConfig(const QString &host, const QString &port);
    Q_INVOKABLE void setRuleEnabled(int index, bool on);
    Q_INVOKABLE void setNotify(const QString &key, bool on);
    Q_INVOKABLE void addRule(const QString &name, const QString &condition,
                             const QString &action, const QString &level);
    Q_INVOKABLE void setNtsEnabled(bool on);
    Q_INVOKABLE void seedDemoHistory();
    Q_INVOKABLE void checkUpdates();

signals:
    void sourcesChanged();
    void eventsChanged();
    void recordsChanged();
    void rulesChanged();
    void liveChanged();
    void countersChanged();
    void samplesChanged();
    void thresholdsChanged();
    void pausedChanged();
    void strategyChanged();
    void testChanged();
    void configChanged();
    void settingsChanged();
    void clockChanged();

    void toast(const QString &title, const QString &text, const QString &tone);
    void systemNotify(const QString &title, const QString &body);

private:
    void setupDefaultSources();
    void loadState();
    void saveSources();
    void saveEvents();
    void saveRules();
    void saveSettings();

    void probeAll(const QString &trigger);
    void onProbeFinished(const QString &tag, const QString &host, bool ok, int stratum,
                         double offsetMs, double delayMs, const QString &error);
    void onTestFinished(const QString &tag, const QString &host, bool ok, int stratum,
                        double offsetMs, double delayMs, const QString &error);
    void finalizeCycle(bool forcedTimeout = false);
    void applyCycle(const QString &trigger);
    ClockSource *findSource(const QString &id);
    const ClockSource *selectPrimary() const;
    double sourceScore(const ClockSource &s) const;

    void appendSample(double offsetMs);
    void recordSync(const QString &trigger, const ClockSource &src, bool ok);
    void addEvent(const QString &level, const QString &title, const QString &desc,
                  const QString &tone, bool unread = false);
    bool ruleEnabled(const QString &name) const;
    void raiseAlert(const QString &title, const QString &desc, const QString &tone);
    void notifyUser(const QString &title, const QString &body, const QString &tone);
    void updateCountersDaily();
    QString toneForStatus(const ClockSource &s) const;
    QString statusFor(const ClockSource &s) const;
    void rebuildSourceStatus();

    QVector<ClockSource> m_sources;
    QVector<SyncRecord> m_records;
    QVector<LogEvent> m_events;
    QVector<AlertRule> m_rules;

    QVector<double> m_samples;
    QVector<QDateTime> m_sampleTimes;
    QDateTime m_lastSampleAt;

    NtpProbe *m_probe = nullptr;
    NtpProbe *m_testProbe = nullptr;
    QTimer m_pollTimer;
    QTimer m_tickTimer;
    QTimer m_guardTimer;
    QElapsedTimer m_cycleClock;

    QString m_primaryId;
    bool m_syncing = false;
    bool m_paused = false;
    QString m_cycleTrigger;
    QSet<QString> m_cycleIds;
    int m_pending = 0;
    bool m_alertHigh = false;
    bool m_alertSevere = false;
    int m_warnStreak = 0;
    int m_severeStreak = 0;
    qint64 m_lastSwitchEventMs = 0;
    bool m_allDownAlerted = false;
    double m_stepAccum = 0.0;
    qint64 m_lastStepMs = 0;

    double m_offsetMs = 0.0;
    double m_delayMs = 0.0;
    double m_prevDelayMs = 0.0;
    int m_stratum = 0;
    qint64 m_lastSyncMs = 0;

    int m_totalSyncs = 0;
    int m_todaySyncs = 0;
    QString m_counterDate;

    double m_maxDeviationMs = 0.0;
    double m_jitterMs = 0.0;

    int m_warnMs = 5;
    int m_severeMs = 50;
    int m_sampleInterval = 4;
    QString m_strategy = QStringLiteral("层级优先");

    QString m_lastTestText = QStringLiteral("尚未测试");
    int m_testPending = 0;
    int m_testOk = 0;

    int m_pollSec = 4;
    bool m_ntsEnabled = false;

    QString m_themeMode = QStringLiteral("system");
    bool m_systemDark = false;
    QString m_density = QStringLiteral("紧凑");
    bool m_autostart = false;
    bool m_trayEnabled = true;
    QString m_closeAction = QStringLiteral("退出程序");
    QString m_logRetention = QStringLiteral("最近 30 天");
    bool m_uploadEnabled = false;
    bool m_notifySystem = true;
    bool m_notifyMail = true;
    bool m_notifyWebhook = false;
    bool m_keepLocalTime = true;
    bool m_allowWriteBack = false;
    bool m_snapshotBefore = true;

    QSettings m_store;
};
