#ifndef MOCKRECOMMENDATIONSERVICE_H
#define MOCKRECOMMENDATIONSERVICE_H

#include "irecommendationservice.h"

#include <QJsonArray>
#include <QJsonObject>

// Временная заглушка без хранения данных об учебных заведениях.
// Данные поступают извне (от второго разработчика).
class MockRecommendationService : public IRecommendationService
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit MockRecommendationService(QObject *parent = nullptr);

    void submitRequest(const QJsonObject &request) override;
    bool isBusy() const override { return m_busy; }

    // Вспомогательный слот для передачи внешнего JSON-ответа (например, при интеграции)
    Q_INVOKABLE void deliverExternalResults(const QJsonArray &results);

private:
    QJsonObject m_lastRequest;
    bool m_busy = false;
};

#endif // MOCKRECOMMENDATIONSERVICE_H