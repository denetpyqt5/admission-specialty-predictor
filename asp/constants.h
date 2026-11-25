#ifndef CONSTANTS_H
#define CONSTANTS_H

#include <QMap>
#include <QObject>
#include <QProcessEnvironment>
#include <QString>
#include <QStringList>
#include <QtQml/qqmlregistration.h>

class AppConstants : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QStringList directions READ directions CONSTANT)
    Q_PROPERTY(QStringList studyForms READ studyForms CONSTANT)
    Q_PROPERTY(QStringList examSubjects READ examSubjects CONSTANT)
    Q_PROPERTY(QStringList languageExamSubjects READ languageExamSubjects CONSTANT)
    Q_PROPERTY(QStringList profileExamSubjects READ profileExamSubjects CONSTANT)

public:
    explicit AppConstants(QObject *parent = nullptr)
        : QObject(parent)
    {
    }

    // Конфигурация эндпоинта (заготовка для интеграции с бэкендом)
    static QString configuredApiEndpoint()
    {
        return QProcessEnvironment::systemEnvironment()
        .value(QStringLiteral("ASP_API_ENDPOINT"), QString());
    }

    QStringList directions() const
    {
        return {
            tr("IT"),
            tr("Медицина"),
            tr("Экономика"),
            tr("Техника"),
            tr("Дизайн"),
            tr("Педагогика")
        };
    }

    Q_INVOKABLE QStringList profilesForDirection(const QString &direction) const
    {
        const QMap<QString, QStringList> map = {
            { tr("IT"), {
                           tr("Программирование"),
                           tr("Сети"),
                           tr("Кибербезопасность")
                       }},
            { tr("Медицина"), {
                                 tr("Сестринское дело"),
                                 tr("Лечебное дело"),
                                 tr("Фармация")
                             }},
            { tr("Экономика"), {
                                  tr("Бухгалтерский учёт"),
                                  tr("Банковское дело"),
                                  tr("Маркетинг")
                              }},
            { tr("Техника"), {
                                tr("Электроника и автоматика"),
                                tr("Машиностроение"),
                                tr("Автосервис")
                            }},
            { tr("Дизайн"), {
                               tr("Графический дизайн"),
                               tr("Веб-дизайн"),
                               tr("Дизайн интерьера")
                           }},
            { tr("Педагогика"), {
                                   tr("Дошкольное образование"),
                                   tr("Начальное образование"),
                                   tr("Иностранные языки")
                               }}
        };

        return map.value(direction);
    }

    QStringList studyForms() const
    {
        return {
            tr("Бюджет"),
            tr("Платно")
        };
    }

    // Обязательный языковой ЦЭ
    QStringList languageExamSubjects() const
    {
        return {
            tr("Русский"),
            tr("Белорусский")
        };
    }

    // Профильные предметы (для второго ЦЭ и для ЦТ)
    QStringList profileExamSubjects() const
    {
        return {
            tr("Математика"),
            tr("Физика"),
            tr("Химия"),
            tr("Биология"),
            tr("История Беларуси"),
            tr("Всемирная история"),
            tr("География"),
            tr("Английский")
        };
    }

    // Полный список предметов
    QStringList examSubjects() const
    {
        QStringList all = profileExamSubjects();
        all.append(languageExamSubjects());
        return all;
    }
};

#endif // CONSTANTS_H