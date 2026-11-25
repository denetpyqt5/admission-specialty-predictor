#ifndef IRECOMMENDATIONSERVICE_H
#define IRECOMMENDATIONSERVICE_H

#include <QJsonArray>
#include <QJsonObject>
#include <QObject>
#include <QString>
#include <QtQml/qqmlregistration.h>

class IRecommendationService : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("IRecommendationService is an abstract interface")

    Q_PROPERTY(bool busy READ isBusy NOTIFY busyChanged)
    Q_PROPERTY(QString endpoint READ endpoint WRITE setEndpoint NOTIFY endpointChanged)

public:
    explicit IRecommendationService(QObject *parent = nullptr)
        : QObject(parent)
    {
    }
    ~IRecommendationService() override = default;

    // Асинхронная отправка JSON-запроса на подбор специальностей
    Q_INVOKABLE virtual void submitRequest(const QJsonObject &request) = 0;

    virtual bool isBusy() const = 0;

    QString endpoint() const { return m_endpoint; }
    void setEndpoint(const QString &url)
    {
        if (m_endpoint == url)
            return;
        m_endpoint = url;
        emit endpointChanged();
    }

signals:
    void resultsReady(const QJsonArray &results);
    void errorOccurred(const QString &errorMessage);
    void busyChanged();
    void endpointChanged();

private:
    QString m_endpoint;
};

#endif // IRECOMMENDATIONSERVICE_H