import 'package:shamsi_date/shamsi_date.dart';

class IranHoliday {
  const IranHoliday(this.month, this.day, this.title);
  final int month;
  final int day;
  final String title;
}

class IranHolidays {
  // تعطیلات ثابت خورشیدی. مناسبت‌های قمری سال‌به‌سال متغیرند و در لایه داده
  // نسخه‌های بعدی با دیتاست سالانه به‌روزرسانی می‌شوند.
  static const fixedSolar = <IranHoliday>[
    IranHoliday(1, 1, 'نوروز'),
    IranHoliday(1, 2, 'عید نوروز'),
    IranHoliday(1, 3, 'عید نوروز'),
    IranHoliday(1, 4, 'عید نوروز'),
    IranHoliday(1, 12, 'روز جمهوری اسلامی ایران'),
    IranHoliday(1, 13, 'روز طبیعت'),
    IranHoliday(3, 14, 'رحلت امام خمینی'),
    IranHoliday(3, 15, 'قیام ۱۵ خرداد'),
    IranHoliday(11, 22, 'پیروزی انقلاب اسلامی ایران'),
    IranHoliday(12, 29, 'ملی شدن صنعت نفت ایران'),
  ];

  List<String> forDate(Jalali date) => fixedSolar
      .where((h) => h.month == date.month && h.day == date.day)
      .map((h) => h.title)
      .toList();

  bool isHoliday(Jalali date) =>
      date.toDateTime().weekday == DateTime.friday || forDate(date).isNotEmpty;
}
