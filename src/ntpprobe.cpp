#include "ntpprobe.h"

#include <QDateTime>
#include <QHostInfo>
#include <QTcpSocket>
#include <QTimer>
#include <QUdpSocket>
#include <QtEndian>

#include <chrono>
#include <cmath>

namespace {
constexpr double kNtpDelta = 2208988800.0; // seconds between 1900-01-01 and 1970-01-01

double wallSeconds()
{
    using namespace std::chrono;
    return duration<double>(system_clock::now().time_since_epoch()).count();
}

void putU32(uchar *p, quint32 v)
{
    qToBigEndian<quint32>(v, p);
}

quint32 getU32(const uchar *p)
{
    return qFromBigEndian<quint32>(p);
}
} // namespace

NtpProbe::NtpProbe(QObject *parent)
    : QObject(parent)
{
}

NtpProbe::~NtpProbe()
{
    const auto pendings = m_pending;
    for (const Pending &p : pendings) {
        if (p.timer)
            p.timer->stop();
        if (p.sock)
            p.sock->deleteLater();
    }
    m_pending.clear();
}

bool NtpProbe::busy(const QString &tag) const
{
    for (const Pending &p : m_pending) {
        if (p.tag == tag)
            return true;
    }
    return false;
}

void NtpProbe::query(const QString &tag, const QString &host, int port, int timeoutMs)
{
    if (host.trimmed().isEmpty() || busy(tag))
        return;

    const QString key = host.trimmed();
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    if (m_dnsCache.contains(key) && now - m_dnsStamp.value(key) < 10 * 60 * 1000) {
        startQuery(tag, key, port, m_dnsCache.value(key), timeoutMs);
        return;
    }

    QHostInfo::lookupHost(key, this, [this, tag, key, port, timeoutMs](const QHostInfo &info) {
        if (info.error() != QHostInfo::NoError || info.addresses().isEmpty()) {
            emit finished(tag, key, false, 0, 0, 0,
                          QStringLiteral("DNS 解析失败：%1").arg(info.errorString()));
            return;
        }
        QHostAddress chosen = info.addresses().first();
        for (const QHostAddress &a : info.addresses()) {
            if (a.protocol() == QAbstractSocket::IPv4Protocol) {
                chosen = a;
                break;
            }
        }
        m_dnsCache.insert(key, chosen);
        m_dnsStamp.insert(key, QDateTime::currentMSecsSinceEpoch());
        startQuery(tag, key, port, chosen, timeoutMs);
    });
}

void NtpProbe::startQuery(const QString &tag, const QString &host, int port,
                          const QHostAddress &addr, int timeoutMs)
{
    auto *sock = new QUdpSocket(this);
    const bool v4 = addr.protocol() == QAbstractSocket::IPv4Protocol;
    const bool bound = sock->bind(v4 ? QHostAddress::AnyIPv4 : QHostAddress::AnyIPv6, 0);
    if (!bound) {
        emit finished(tag, host, false, 0, 0, 0,
                      QStringLiteral("本地 UDP 端口绑定失败：%1").arg(sock->errorString()));
        sock->deleteLater();
        return;
    }

    QByteArray packet(48, '\0');
    uchar *d = reinterpret_cast<uchar *>(packet.data());
    d[0] = 0x23; // LI = 0, VN = 4, Mode = 3 (client)
    const double t1 = wallSeconds();
    const double ntpNow = t1 + kNtpDelta;
    const quint32 sec = static_cast<quint32>(ntpNow);
    const quint32 frac = static_cast<quint32>((ntpNow - sec) * 4294967296.0);
    putU32(d + 40, sec);
    putU32(d + 44, frac);

    Pending p;
    p.tag = tag;
    p.host = host;
    p.port = port;
    p.t1 = t1;
    p.sock = sock;
    p.timer = new QTimer(sock);
    p.timer->setSingleShot(true);
    m_pending.insert(sock, p);

    connect(sock, &QUdpSocket::errorOccurred, this, [this, sock](QAbstractSocket::SocketError) {
        finish(sock, false, 0, 0, 0,
               QStringLiteral("网络错误：%1").arg(sock->errorString()));
    });

    connect(sock, &QUdpSocket::readyRead, this, [this, sock]() {
        while (sock->hasPendingDatagrams()) {
            QByteArray buf;
            buf.resize(static_cast<int>(sock->pendingDatagramSize()));
            const qint64 n = sock->readDatagram(buf.data(), buf.size());
            if (n < 48)
                continue;

            const uchar *r = reinterpret_cast<const uchar *>(buf.constData());
            const int mode = r[0] & 0x07;
            const int stratum = r[1];
            if (mode != 4) {
                finish(sock, false, 0, 0, 0, QStringLiteral("响应模式无效"));
                return;
            }
            if (stratum == 0) {
                const QString ref = QString::fromLatin1(buf.mid(12, 4));
                finish(sock, false, 0, 0, 0, QStringLiteral("服务器拒绝（KoD %1）").arg(ref));
                return;
            }

            const quint32 recSec = getU32(r + 32);
            const quint32 recFrac = getU32(r + 36);
            const quint32 xmtSec = getU32(r + 40);
            const quint32 xmtFrac = getU32(r + 44);
            if (xmtSec == 0) {
                finish(sock, false, 0, 0, 0, QStringLiteral("服务器时间戳为空"));
                return;
            }

            const double t2 = double(recSec) + double(recFrac) / 4294967296.0 - kNtpDelta;
            const double t3 = double(xmtSec) + double(xmtFrac) / 4294967296.0 - kNtpDelta;
            const double t4 = wallSeconds();
            const Pending pd = m_pending.value(sock);

            const double offset = ((t2 - pd.t1) + (t3 - t4)) / 2.0 * 1000.0;
            double delay = ((t4 - pd.t1) - (t3 - t2)) * 1000.0;
            if (delay < 0.0)
                delay = 0.0;

            if (!std::isfinite(offset) || std::abs(offset) > 86400000.0) {
                finish(sock, false, 0, 0, 0, QStringLiteral("时间戳异常"));
                return;
            }
            finish(sock, true, stratum, offset, delay, QString());
            return;
        }
    });

    p.timer->setInterval(timeoutMs);
    connect(p.timer, &QTimer::timeout, sock, [this, sock]() {
        finish(sock, false, 0, 0, 0, QStringLiteral("超时无响应"));
    });
    p.timer->start();

    sock->writeDatagram(packet, addr, static_cast<quint16>(port));
}

void NtpProbe::finish(QUdpSocket *sock, bool ok, int stratum, double offsetMs,
                      double delayMs, const QString &error)
{
    if (!m_pending.contains(sock))
        return;
    const Pending p = m_pending.take(sock);
    if (p.timer)
        p.timer->stop();
    sock->disconnect(this);
    sock->close();
    sock->deleteLater();
    emit finished(p.tag, p.host, ok, stratum, offsetMs, delayMs, error);
}
