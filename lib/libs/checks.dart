import 'package:kepler_app/libs/indiware.dart';
import 'package:kepler_app/libs/logging.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/tabs/hourtable/ht_data.dart';

/// ich würde mal behaupten, die Funktion erklärt sich am Namen (testet Zugriff auf Schüler- und Lehrerplan)
/// returns: null = request error, usertype.(pupil|teacher) = success, usertype.nobody = invalid creds
Future<UserType?> checkIndiwareData(String host, String username, String password) async {
  try {
    final lres = await authRequest(lUrlMLeXmlUrl(host), username, password);
    // if null, throw -> to catch block
    if (lres!.statusCode == 401) { // if teacher auth failed, try again with pupil auth
      final sres = await authRequest(sUrlMKlXmlUrl(host), username, password);
      if (sres!.statusCode == 401) return UserType.nobody;
      if (sres.statusCode != 200) return null;
      return UserType.pupil;
    }
    if (lres.statusCode != 200) return null;
    return UserType.teacher;
  } catch (e, s) {
    logCatch("indiware-.check", e, s);
    return null;
  }
}

/// überprüft alle Metadaten zum Stundenplanlogin:
/// - aktuelle Klassen / Lehrercodes, um auf Vorhandensein des Ausgewählten zu prüfen
/// - verfügbare Klassen und Fächer
/// - schulfreie Tage
/// Außerdem wird die letzte Aktualisierung gespeichert, damit der Benutzer auf alte Daten hingewiesen werden kann.
/// (alte Daten = letzte Aktualisierung vor min. 14 Tagen)
Future<String?> checkAndUpdateSPMetaData(String vpHost, String vpUser, String vpPass, UserType utype, StuPlanData stuPlanData) async {
  List<DateTime>? updatedFreeDays;
  String? output;
  if (utype == UserType.teacher && stuPlanData.availableTeachers != null && stuPlanData.lastAvailTeachersUpdate.difference(DateTime.now()).abs().inDays >= 14) {
    final (data, _) = await getLehrerXmlLeData(vpHost, vpUser, vpPass);
    if (data != null) {
      stuPlanData.loadDataFromLeData(data);
      // check if selected teacher code doesn't exist anymore (because the school removed it)
      if (stuPlanData.selectedTeacherName != null && data?.teachers.map((t) => t.teacherCode).contains(stuPlanData.selectedTeacherName!) == false) {
        stuPlanData.selectedTeacherName = null;
        output ??= "Achtung! Der gewählte Lehrer ist nicht mehr in den Schuldaten vorhanden. Der Stundenplan muss neu eingerichtet werden.";
      }
      updatedFreeDays = data.holidays.holidayDates;
    } else {
      output ??= "Hinweis: Die Stundenplan-Daten sind nicht mehr aktuell. Bitte mit dem Internet verbinden.";
    }
  } else if (
    utype != UserType.nobody &&
    (
      (stuPlanData.availableClasses != null && stuPlanData.lastAvailClassesUpdate.difference(DateTime.now()).abs().inDays >= 14)
      || (stuPlanData.availableSubjects.isNotEmpty && stuPlanData.lastAvailSubjectsUpdate.difference(DateTime.now()).abs().inDays >= 14)
    )
  ) {
    final (rawData, _) = await getKlassenXML(vpHost, vpUser, vpPass);
    if (rawData != null) {
      final data = xmlToKlData(rawData);
      stuPlanData.loadDataFromKlData(data);
      // check if selected class name doesn't exist anymore (because the school removed it)
      if (stuPlanData.selectedClassName != null && data?.classes.map((t) => t.className).contains(stuPlanData.selectedClassName!) == false) {
        stuPlanData.selectedClassName = null;
        output ??= "Achtung! Die gewählte Klasse ist nicht mehr in den Schuldaten vorhanden. Der Stundenplan muss neu eingerichtet werden.";
      }
      IndiwareDataManager.setKlassenXmlData(rawData);
      updatedFreeDays = data.holidays.holidayDates;
    } else {
      output ??= "Hinweis: Die Stundenplan-Daten sind nicht mehr aktuell. Bitte mit dem Internet verbinden.";
    }
  }
  if (stuPlanData.lastHolidayDatesUpdate.difference(DateTime.now()).abs().inDays >= 14) {
    if (updatedFreeDays != null) {
      stuPlanData.holidayDates = updatedFreeDays;
      stuPlanData.lastHolidayDatesUpdate = DateTime.now();
    } else {
      final (rawData, _) = await getKlassenXML(vpHost, vpUser, vpPass);
      if (rawData != null) {
        final data = xmlToKlData(rawData);
        stuPlanData.holidayDates = data.holidays.holidayDates;
        stuPlanData.lastHolidayDatesUpdate = DateTime.now();
        IndiwareDataManager.setKlassenXmlData(rawData);
      } else {
        output ??= "Hinweis: Die Liste der schulfreien Tage ist nicht mehr aktuell. Bitte mit dem Internet verbinden.";
      }
    }
  }
  return output;
}
