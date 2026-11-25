#ifndef APPLICANT_H
#define APPLICANT_H

#include <QJsonObject>
#include <QList>
#include <QObject>
#include <QString>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

struct Subject
{
    enum ExamType {
        CE,
        CT
    };

    qint32 score = 0;
    QString subjectName;
    ExamType examType = CE;

    Subject() = default;
    Subject(const QString &name, qint32 pts, ExamType type = CE)
        : score(pts), subjectName(name), examType(type) {}
    ~Subject() = default;

    static QString examTypeToString(ExamType type);
    static bool examTypeFromString(const QString &str, ExamType &outType);
};

class Applicant : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Applicant is an abstract base class")

    // Свойства Applicant
    Q_PROPERTY(QString fullName READ getFullName WRITE setFullName NOTIFY fullNameChanged)
    Q_PROPERTY(qreal gpa READ getGPA WRITE setGPA NOTIFY gpaChanged)

public:
    explicit Applicant(QObject *parent = nullptr);
    ~Applicant() override = default;

    // Геттер и сеттер для имени
    QString getFullName() const { return m_fullName; }
    void setFullName(const QString &val);

    // Геттер и сеттер для среднего балла (10-балльная шкала: 0.0–10.0)
    qreal getGPA() const { return m_gpa; }
    void setGPA(qreal points);

    // Пересчёт среднего балла в 100-балльную шкалу
    qint32 getGPA100() const;

    // Подсчёт итогового балла
    Q_INVOKABLE virtual qint32 countTotalScore() = 0;

    // Сериализация в JSON для отправки в сервис рекомендаций
    Q_INVOKABLE virtual QJsonObject toJson();

signals:
    void fullNameChanged();
    void gpaChanged();
    void totalScoreCounted();
    void errorOccurred(const QString &errorMessage);

private:
    QString m_fullName;     // ФИО
    qreal m_gpa;            // средний балл (0.0–10.0)
};

// Поступающий в ССУЗ (колледж)
class CollegeApplicant : public Applicant
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString direction READ direction WRITE setDirection NOTIFY directionChanged)
    Q_PROPERTY(QString profile READ profile WRITE setProfile NOTIFY profileChanged)
    Q_PROPERTY(QString studyForm READ studyForm WRITE setStudyForm NOTIFY studyFormChanged)

public:
    explicit CollegeApplicant(QObject *parent = nullptr);

    QString direction() const { return m_direction; }
    void setDirection(const QString &val);

    QString profile() const { return m_profile; }
    void setProfile(const QString &val);

    QString studyForm() const { return m_studyForm; }
    void setStudyForm(const QString &val);

    qint32 countTotalScore() override;
    QJsonObject toJson() override;

signals:
    void directionChanged();
    void profileChanged();
    void studyFormChanged();

private:
    QString m_direction;
    QString m_profile;
    QString m_studyForm;
};

// Поступающий в ВУЗ (университет)
class UniversityApplicant : public Applicant
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QVariantList exams READ exams NOTIFY examsChanged)

public:
    explicit UniversityApplicant(QObject *parent = nullptr);

    void addSubject(const Subject &subject);

    Q_INVOKABLE bool addExam(const QString &subjectName, qint32 score, const QString &examType);
    Q_INVOKABLE bool setExams(const QVariantList &examList);
    Q_INVOKABLE void clearExams();
    Q_INVOKABLE QVariantList exams() const;
    Q_INVOKABLE QString validateExams() const;

    qint32 countTotalScore() override;
    QJsonObject toJson() override;

signals:
    void examsChanged();

private:
    QList<Subject> subjects;
};

#endif // APPLICANT_H