#include "applicant.h"

#include <QJsonArray>
#include <QSet>
#include <QVariantMap>
#include <QtMath>
#include <utility>

namespace {
bool isStateLanguageSubject(const QString &subjectName)
{
    const QString s = subjectName.trimmed().toLower();
    return s == QStringLiteral("русский") || s == QStringLiteral("белорусский");
}
} // namespace

// ==========================================
// Subject
// ==========================================

QString Subject::examTypeToString(ExamType type)
{
    return (type == CT) ? QStringLiteral("CT") : QStringLiteral("CE");
}

bool Subject::examTypeFromString(const QString &str, ExamType &outType)
{
    const QString normalized = str.trimmed().toUpper();
    if (normalized == QStringLiteral("CE") || normalized == QStringLiteral("ЦЭ")) {
        outType = CE;
        return true;
    }
    if (normalized == QStringLiteral("CT") || normalized == QStringLiteral("ЦТ")) {
        outType = CT;
        return true;
    }
    return false;
}

// ==========================================
// Applicant
// ==========================================

Applicant::Applicant(QObject *parent)
    : QObject(parent), m_gpa(0.0)
{
}

void Applicant::setFullName(const QString &val)
{
    const QString trimmed = val.trimmed();
    if (m_fullName == trimmed)
        return;

    m_fullName = trimmed;
    emit fullNameChanged();
}

void Applicant::setGPA(qreal points)
{
    if (points < 0.0 || points > 10.0) {
        emit errorOccurred(tr("Средний балл аттестата должен находиться в диапазоне от 0.0 до 10.0."));
        return;
    }

    if (qFuzzyCompare(m_gpa + 1.0, points + 1.0))
        return;

    m_gpa = points;
    emit gpaChanged();
}

qint32 Applicant::getGPA100() const
{
    return qRound(m_gpa * 10.0);
}

QJsonObject Applicant::toJson()
{
    QJsonObject obj;
    obj.insert(QStringLiteral("fullName"), m_fullName);
    obj.insert(QStringLiteral("gpa10"), m_gpa);
    obj.insert(QStringLiteral("gpa100"), getGPA100());
    return obj;
}

// ==========================================
// CollegeApplicant
// ==========================================

CollegeApplicant::CollegeApplicant(QObject *parent)
    : Applicant(parent)
{
}

void CollegeApplicant::setDirection(const QString &val)
{
    if (m_direction == val)
        return;

    m_direction = val;
    emit directionChanged();
}

void CollegeApplicant::setProfile(const QString &val)
{
    if (m_profile == val)
        return;

    m_profile = val;
    emit profileChanged();
}

void CollegeApplicant::setStudyForm(const QString &val)
{
    if (m_studyForm == val)
        return;

    m_studyForm = val;
    emit studyFormChanged();
}

void CollegeApplicant::setRegions(const QStringList &val)
{
    if (m_regions == val)
        return;

    m_regions = val;
    emit regionsChanged();
}

qint32 CollegeApplicant::countTotalScore()
{
    const qint32 total = getGPA100();
    emit totalScoreCounted();
    return total;
}

QJsonObject CollegeApplicant::toJson()
{
    QJsonObject obj = Applicant::toJson();
    obj.insert(QStringLiteral("type"), QStringLiteral("college"));
    obj.insert(QStringLiteral("totalScore"), countTotalScore());
    obj.insert(QStringLiteral("regions"), QJsonArray::fromStringList(m_regions));

    QJsonObject interests;
    interests.insert(QStringLiteral("direction"), m_direction);
    interests.insert(QStringLiteral("profile"), m_profile);
    interests.insert(QStringLiteral("studyForm"), m_studyForm);

    obj.insert(QStringLiteral("interests"), interests);
    return obj;
}

// ==========================================
// UniversityApplicant
// ==========================================

UniversityApplicant::UniversityApplicant(QObject *parent)
    : Applicant(parent), m_studyForm(tr("Бюджет"))
{
}

void UniversityApplicant::addSubject(const Subject &subject)
{
    if (subject.subjectName.trimmed().isEmpty()) {
        emit errorOccurred(tr("Название предмета не может быть пустым."));
        return;
    }
    if (subject.score < 0 || subject.score > 100) {
        emit errorOccurred(tr("Балл за экзамен должен быть в диапазоне от 0 до 100."));
        return;
    }

    for (const Subject &existing : std::as_const(subjects)) {
        if (existing.subjectName.compare(subject.subjectName, Qt::CaseInsensitive) == 0) {
            emit errorOccurred(tr("Предмет «%1» уже добавлен. Предметы не должны повторяться.")
                                   .arg(subject.subjectName));
            return;
        }
    }

    subjects.append(subject);
    emit examsChanged();
}

bool UniversityApplicant::addExam(const QString &subjectName, qint32 score, const QString &examType)
{
    Subject::ExamType parsedType = Subject::CE;
    if (!Subject::examTypeFromString(examType, parsedType)) {
        emit errorOccurred(tr("Некорректный тип экзамена: %1. Ожидается CE или CT.").arg(examType));
        return false;
    }

    const int countBefore = subjects.size();
    addSubject(Subject(subjectName.trimmed(), score, parsedType));
    return subjects.size() > countBefore;
}

bool UniversityApplicant::setExams(const QVariantList &examList)
{
    QList<Subject> validated;
    QSet<QString> seenSubjects;
    int ceCount = 0;
    int ctCount = 0;
    int ceLanguageCount = 0;

    for (const QVariant &item : examList) {
        const QVariantMap map = item.toMap();
        const QString name = map.value(QStringLiteral("subject")).toString().trimmed();
        bool scoreOk = false;
        const qint32 score = map.value(QStringLiteral("score")).toInt(&scoreOk);
        const QString typeStr = map.value(QStringLiteral("examType")).toString();

        Subject::ExamType type = Subject::CE;
        if (name.isEmpty()) {
            emit errorOccurred(tr("Выберите все предметы для экзаменов."));
            return false;
        }
        if (!scoreOk || score < 0 || score > 100) {
            emit errorOccurred(tr("Балл по предмету «%1» должен быть от 0 до 100.").arg(name));
            return false;
        }
        if (!Subject::examTypeFromString(typeStr, type)) {
            emit errorOccurred(tr("Некорректный тип экзамена для предмета «%1».").arg(name));
            return false;
        }

        const QString key = name.toLower();
        if (seenSubjects.contains(key)) {
            emit errorOccurred(tr("Предметы экзаменов не должны повторяться (дублируется «%1»).").arg(name));
            return false;
        }
        seenSubjects.insert(key);

        const bool isLang = isStateLanguageSubject(name);
        if (type == Subject::CE) {
            ++ceCount;
            if (isLang)
                ++ceLanguageCount;
        } else {
            if (isLang) {
                emit errorOccurred(tr("Русский и белорусский языки сдаются в рамках ЦЭ, а не ЦТ."));
                return false;
            }
            ++ctCount;
        }

        validated.append(Subject(name, score, type));
    }

    if (validated.size() != 3 || ceCount != 2 || ctCount != 1) {
        emit errorOccurred(tr("Необходимо указать ровно 3 экзамена: 2 ЦЭ и 1 ЦТ."));
        return false;
    }

    if (ceLanguageCount != 1) {
        emit errorOccurred(tr("Один из экзаменов ЦЭ должен быть Русский или Белорусский язык, а второй — профильный предмет."));
        return false;
    }

    subjects = std::move(validated);
    emit examsChanged();
    return true;
}

void UniversityApplicant::clearExams()
{
    if (subjects.isEmpty())
        return;

    subjects.clear();
    emit examsChanged();
}

QVariantList UniversityApplicant::exams() const
{
    QVariantList result;
    result.reserve(subjects.size());

    for (const Subject &s : std::as_const(subjects)) {
        QVariantMap map;
        map.insert(QStringLiteral("subject"), s.subjectName);
        map.insert(QStringLiteral("score"), s.score);
        map.insert(QStringLiteral("examType"), Subject::examTypeToString(s.examType));
        result.append(map);
    }
    return result;
}

QString UniversityApplicant::validateExams() const
{
    if (subjects.size() != 3)
        return tr("Необходимо указать ровно 3 экзамена: 2 ЦЭ и 1 ЦТ.");

    QSet<QString> seen;
    int ceCount = 0;
    int ctCount = 0;
    int ceLanguageCount = 0;

    for (const Subject &s : std::as_const(subjects)) {
        if (s.subjectName.trimmed().isEmpty())
            return tr("У всех экзаменов должен быть выбран предмет.");
        if (s.score < 0 || s.score > 100)
            return tr("Баллы по всем экзаменам должны быть в диапазоне от 0 до 100.");

        const QString key = s.subjectName.trimmed().toLower();
        if (seen.contains(key))
            return tr("Предметы экзаменов не должны повторяться.");
        seen.insert(key);

        const bool isLang = isStateLanguageSubject(s.subjectName);
        if (s.examType == Subject::CE) {
            ++ceCount;
            if (isLang)
                ++ceLanguageCount;
        } else {
            if (isLang)
                return tr("Русский и белорусский языки не могут быть выбраны для ЦТ.");
            ++ctCount;
        }
    }

    if (ceCount != 2 || ctCount != 1)
        return tr("Необходимо указать ровно 2 ЦЭ и 1 ЦТ.");

    if (ceLanguageCount != 1)
        return tr("Один из экзаменов ЦЭ должен быть Русский или Белорусский язык.");

    return QString();
}

void UniversityApplicant::setCities(const QStringList &val)
{
    if (m_cities == val)
        return;

    m_cities = val;
    emit citiesChanged();
}

void UniversityApplicant::setStudyForm(const QString &val)
{
    if (m_studyForm == val)
        return;

    m_studyForm = val;
    emit studyFormChanged();
}

qint32 UniversityApplicant::countTotalScore()
{
    qint32 total = getGPA100();
    for (const Subject &s : std::as_const(subjects)) {
        total += s.score;
    }

    emit totalScoreCounted();
    return total;
}

QJsonObject UniversityApplicant::toJson()
{
    QJsonObject obj = Applicant::toJson();
    obj.insert(QStringLiteral("type"), QStringLiteral("university"));

    const QString form = m_studyForm.trimmed().isEmpty() ? tr("Бюджет") : m_studyForm.trimmed();
    const bool isBudget = (form.compare(tr("Бюджет"), Qt::CaseInsensitive) == 0
                           || form.compare(QStringLiteral("бюджет"), Qt::CaseInsensitive) == 0);

    obj.insert(QStringLiteral("studyForm"), form);
    obj.insert(QStringLiteral("budgetPriority"), isBudget);
    obj.insert(QStringLiteral("cities"), QJsonArray::fromStringList(m_cities));

    QJsonArray examsArray;
    for (const Subject &s : std::as_const(subjects)) {
        QJsonObject examObj;
        examObj.insert(QStringLiteral("subject"), s.subjectName);
        examObj.insert(QStringLiteral("score"), s.score);
        examObj.insert(QStringLiteral("examType"), Subject::examTypeToString(s.examType));
        examsArray.append(examObj);
    }

    obj.insert(QStringLiteral("exams"), examsArray);
    obj.insert(QStringLiteral("totalScore"), countTotalScore());
    return obj;
}