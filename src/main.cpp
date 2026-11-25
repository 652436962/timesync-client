#include "ntpprobe.h"
#include "synccore.h"

#include <QApplication>
#include <QCommandLineOption>
#include <QCommandLineParser>
#include <QFontDatabase>
#include <QMenu>
#include <QPainter>
#include <QPixmap>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QSystemTrayIcon>
#include <QTimer>

static QIcon makeAppIcon()
{
    QPixmap pm(64, 64);
    pm.fill(Qt::transparent);
    QPainter p(&pm);
    p.setRenderHint(QPainter::Antialiasing);
    p.setPen(Qt::NoPen);
    p.setBrush(QColor("#1F6F5C"));
    p.drawRoundedRect(QRectF(2, 2, 60, 60), 16, 16);
    p.setPen(QPen(QColor("#7FE3C2"), 4));
    p.setBrush(Qt::NoBrush);
    p.drawEllipse(QPointF(32, 34), 17, 17);
    p.drawLine(QPointF(32, 34), QPointF(32, 23));
    p.drawLine(QPointF(32, 34), QPointF(40, 39));
    p.setBrush(QColor("#FFFFFF"));
    p.setPen(Qt::NoPen);
    p.drawRoundedRect(QRectF(26, 14, 12, 4), 2, 2);
    p.end();
    return QIcon(pm);
}

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    QApplication::setOrganizationName(QStringLiteral("TimeSync"));
    QApplication::setApplicationName(QStringLiteral("TimeSync Client"));
    QApplication::setApplicationVersion(QStringLiteral("2.4.1"));

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("TimeSync client - real SNTP monitor"));
    parser.addHelpOption();
    parser.addVersionOption();
    QCommandLineOption pageOpt(QStringLiteral("page"), QStringLiteral("Initial page index (0-7)"),
                               QStringLiteral("n"));
    QCommandLineOption shotOpt(QStringLiteral("shot"), QStringLiteral("Grab window to PNG and exit"),
                               QStringLiteral("file"));
    QCommandLineOption demoOpt(QStringLiteral("demo"), QStringLiteral("Seed demo chart history"));
    QCommandLineOption delayOpt(QStringLiteral("shot-delay"), QStringLiteral("Screenshot delay in ms"),
                                QStringLiteral("ms"), QStringLiteral("6000"));
    parser.addOptions({pageOpt, shotOpt, demoOpt, delayOpt});
    parser.process(app);

    if (parser.isSet("shot") && qEnvironmentVariableIsEmpty("QT_QPA_PLATFORM"))
        qputenv("QT_QPA_PLATFORM", "offscreen");

    QQuickStyle::setStyle(QStringLiteral("Basic"));

    const QStringList fontFiles = {
        QStringLiteral(":/fonts/Inter-Regular.ttf"),
        QStringLiteral(":/fonts/Inter-Medium.ttf"),
        QStringLiteral(":/fonts/Inter-SemiBold.ttf"),
        QStringLiteral(":/fonts/Inter-Bold.ttf"),
    };
    for (const QString &f : fontFiles)
        QFontDatabase::addApplicationFont(f);

    QFont appFont(QStringLiteral("Inter"));
    appFont.setFamilies({QStringLiteral("Inter"), QStringLiteral("Noto Sans CJK SC")});
    appFont.setPixelSize(13);
    QApplication::setFont(appFont);

    SyncCore core;
    if (parser.isSet("demo"))
        core.seedDemoHistory();

    qmlRegisterUncreatableType<SyncCore>("TimeSync", 1, 0, "SyncCore",
                                         QStringLiteral("Use the Engine context property"));

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("Engine"), &core);
    engine.rootContext()->setContextProperty(QStringLiteral("InitialPage"),
                                             parser.value(pageOpt).toInt());
    engine.rootContext()->setContextProperty(QStringLiteral("ScreenshotMode"),
                                             parser.isSet("shot"));

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
                     []() { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule("TimeSync", "Main");
    if (engine.rootObjects().isEmpty())
        return 1;

    auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().constFirst());
    if (window)
        window->setIcon(makeAppIcon());

    // Tray icon with the app's quick actions.
    QSystemTrayIcon tray(makeAppIcon(), &app);
    tray.setToolTip(QStringLiteral("TimeSync 时间同步客户端"));
    QMenu trayMenu;
    QAction *showAction = trayMenu.addAction(QStringLiteral("显示主窗口"));
    QAction *syncAction = trayMenu.addAction(QStringLiteral("立即同步"));
    trayMenu.addSeparator();
    QAction *quitAction = trayMenu.addAction(QStringLiteral("退出"));
    tray.setContextMenu(&trayMenu);
    QObject::connect(showAction, &QAction::triggered, &app, [window]() {
        if (!window)
            return;
        window->show();
        window->raise();
        window->requestActivate();
    });
    QObject::connect(syncAction, &QAction::triggered, &core, &SyncCore::syncNow);
    QObject::connect(quitAction, &QAction::triggered, &app, []() { QCoreApplication::quit(); });
    QObject::connect(&tray, &QSystemTrayIcon::activated, &app,
                     [window](QSystemTrayIcon::ActivationReason reason) {
                         if (!window)
                             return;
                         if (reason == QSystemTrayIcon::Trigger || reason == QSystemTrayIcon::DoubleClick) {
                             window->setVisible(!window->isVisible());
                             if (window->isVisible()) {
                                 window->raise();
                                 window->requestActivate();
                             }
                         }
                     });
    QObject::connect(&core, &SyncCore::systemNotify, &app,
                     [&tray](const QString &title, const QString &body) {
                         if (tray.isVisible())
                             tray.showMessage(title, body, makeAppIcon(), 5000);
                     });
    auto applyTray = [&tray, &core]() { tray.setVisible(core.trayEnabled()); };
    QObject::connect(&core, &SyncCore::settingsChanged, &app, applyTray);
    applyTray();

    if (parser.isSet("shot") && window) {
        const QString path = parser.value(shotOpt);
        const int delay = parser.value(delayOpt).toInt();
        QTimer::singleShot(delay, &app, [window, path, &app]() {
            const QImage img = window->grabWindow();
            if (!img.isNull() && img.save(path))
                qInfo("saved %s (%dx%d)", qPrintable(path), img.width(), img.height());
            else
                qWarning("failed to save screenshot");
            QCoreApplication::quit();
        });
    }

    return app.exec();
}
