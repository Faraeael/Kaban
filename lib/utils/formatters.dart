import 'package:intl/intl.dart';

final _currency =
    NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 0);
final _currencyCents =
    NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2);
final _dateMonth = DateFormat('MMMM yyyy');
final _dateDay = DateFormat('EEEE, MMM d');
final _dateShort = DateFormat('MMM d');

String peso(double v) => _currency.format(v);
String pesoExact(double v) => _currencyCents.format(v);
String monthLabel(DateTime d) => _dateMonth.format(d);
String dayLabel(DateTime d) => _dateDay.format(d);
String shortDate(DateTime d) => _dateShort.format(d);
