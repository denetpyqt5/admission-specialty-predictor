#include "mockrecommendationservice.h"

MockRecommendationService::MockRecommendationService(QObject *parent)
    : IRecommendationService(parent)
{
}

void MockRecommendationService::submitRequest(const QJsonObject &request)
{
    if (m_busy) {
        emit errorOccurred(tr("Запрос уже выполняется. Дождитесь завершения."));
        return;
    }

    if (request.isEmpty() || !request.contains(QStringLiteral("type"))) {
        emit errorOccurred(tr("Передан пустой или некорректный JSON-запрос."));
        return;
    }

    m_lastRequest = request;

    // Локальные данные об университетах и колледжах не хранятся.
    // Замените MockRecommendationService в main.cpp на реализацию сервиса второго разработчика.
    emit errorOccurred(tr("Сервис подбора ещё не подключён. Ожидается получение данных от внешнего модуля."));
}

void MockRecommendationService::deliverExternalResults(const QJsonArray &results)
{
    if (m_busy) {
        m_busy = false;
        emit busyChanged();
    }

    emit resultsReady(results);
}