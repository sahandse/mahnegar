import 'package:shamsi_date/shamsi_date.dart';

class IranHoliday {
  const IranHoliday(this.year, this.month, this.day, this.title);

  final int? year;
  final int month;
  final int day;
  final String title;
}

class IranHolidays {
  // تعطیلات ثابت خورشیدی در تمام سال‌ها.
  static const fixedSolar = <IranHoliday>[
    IranHoliday(null, 1, 1, 'جشن نوروز / سال نو'),
    IranHoliday(null, 1, 2, 'عید نوروز'),
    IranHoliday(null, 1, 3, 'عید نوروز'),
    IranHoliday(null, 1, 4, 'عید نوروز'),
    IranHoliday(null, 1, 12, 'روز جمهوری اسلامی ایران'),
    IranHoliday(null, 1, 13, 'روز طبیعت'),
    IranHoliday(null, 3, 14, 'رحلت حضرت امام خمینی'),
    IranHoliday(null, 3, 15, 'قیام ۱۵ خرداد'),
    IranHoliday(null, 11, 22, 'پیروزی انقلاب اسلامی ایران'),
    IranHoliday(null, 12, 29, 'روز ملی شدن صنعت نفت ایران'),
  ];

  // تعطیلات متغیر سال ۱۴۰۵ از دیتاست سالانه تقویم رسمی ایران.
  // این داده‌ها تاریخ ثابت حدسی نیستند و برای همین سال به‌صورت صریح نگهداری می‌شوند.
  static const variable1405 = <IranHoliday>[
    IranHoliday(1405, 1, 25, 'شهادت امام جعفر صادق علیه‌السلام'),
    IranHoliday(1405, 3, 7, 'عید سعید قربان'),
    IranHoliday(1405, 4, 4, 'تاسوعای حسینی'),
    IranHoliday(1405, 4, 5, 'عاشورای حسینی'),
    IranHoliday(1405, 6, 9, 'میلاد رسول اکرم و امام جعفر صادق علیه‌السلام'),
    IranHoliday(1405, 8, 23, 'شهادت حضرت فاطمه زهرا سلام‌الله‌علیها'),
    IranHoliday(1405, 10, 2, 'ولادت امام علی علیه‌السلام و روز پدر'),
    IranHoliday(1405, 10, 16, 'مبعث رسول اکرم (ص)'),
    IranHoliday(1405, 11, 4, 'ولادت حضرت قائم (عج) و جشن نیمه شعبان'),
    IranHoliday(1405, 12, 10, 'شهادت حضرت علی علیه‌السلام'),
    IranHoliday(1405, 12, 19, 'عید سعید فطر'),
    IranHoliday(1405, 12, 20, 'تعطیل به مناسبت عید سعید فطر'),
  ];

  List<String> forDate(Jalali date) {
    final result = <String>[];
    for (final h in fixedSolar) {
      if (h.month == date.month && h.day == date.day) result.add(h.title);
    }
    for (final h in variable1405) {
      if (h.year == date.year && h.month == date.month && h.day == date.day) {
        result.add(h.title);
      }
    }
    return result;
  }

  bool isHoliday(Jalali date) =>
      date.toDateTime().weekday == DateTime.friday || forDate(date).isNotEmpty;
}
