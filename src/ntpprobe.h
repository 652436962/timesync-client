#pragma once

#include <QObject>
#include <QHash>
#include <QHostAddress>

class QUdpSocket;
class QTimer;

/*
 * Asynchronous SNTP (RFC 4330) client built on QUdpSocket.
 * One NtpProbe instance can run several queries concurrently; `tag`
 * identifies the caller's request (we use the clock-source id).
 */
class NtpProbe : public QObject
{
    Q_OBJECT
public:
    explicit NtpProbe(QObject *parent = nullptr);
    ~NtpProbe() override;

    void query(const QString &tag, const QString &host, int port = 123, int timeoutMs = 2200);
    bool busy(const QString &tag) const;

signals:
    void finished(const QString &tag, const QString &host, bool ok, int stratum,
                  double offsetMs, double delayMs, const QString &error);

private:
    struct Pending {
        QString tag;
        QString host;
        int port = 123;
        double t1 = 0;
        QUdpSocket *sock = nullptr;
        QTimer *timer = nullptr;
    };

    void startQuery(const QString &tag, const QString &host, int port,
                    const QHostAddress &addr, int timeoutMs);
    void finish(QUdpSocket *sock, bool ok, int stratum, double offsetMs,
                double delayMs, const QString &error);

    QHash<QUdpSocket *, Pending> m_pending;
    QHash<QString, QHostAddress> m_dnsCache;
    QHash<QString, qint64> m_dnsStamp;
};
