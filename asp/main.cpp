#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "constants.h"
#include "mockrecommendationservice.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    // Точка интеграции: для перехода на реальный сервер замените
    // MockRecommendationService на свою реализацию IRecommendationService.
    MockRecommendationService recommendationService;
    recommendationService.setEndpoint(AppConstants::configuredApiEndpoint());

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(
        QStringLiteral("recommendationService"),
        &recommendationService);

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("asp", "Main");

    return QGuiApplication::exec();
}