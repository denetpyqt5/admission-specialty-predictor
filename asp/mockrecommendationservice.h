#ifndef MOCKRECOMMENDATIONSERVICE_H
#define MOCKRECOMMENDATIONSERVICE_H

#include "irecommendationservice.h"

#include <QJsonArray>
#include <QJsonObject>

// Заглушка без локального хранения университетов и колледжей.
// Данные поступают извне (от модуля/сервиса второго разработчика).
class MockRecommendationService : public IRecommendationService
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit MockRecommendationService(QObject *parent = nullptr);

    void submitRequest(const QJsonObject &request) override;
    bool isBusy() const override { return m_busy; }

    QJsonObject lastRequest() const { return m_lastRequest; }

    // Вспомогательный метод для прямой передачи внешнего JSON-ответа
    Q_INVOKABLE void deliverExternalResults(const QJsonArray &results);

private:
    QJsonObject m_lastRequest;
    bool m_busy = false;
};

#endif // MOCKRECOMMENDATIONSERVICE_H