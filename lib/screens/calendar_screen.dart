import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../services/api_service.dart';
import 'lawsuit_detail_screen.dart';
import 'case_detail_screen.dart';
import 'session_detail_screen.dart';
import '../models/hearing_model.dart';
import 'dart:convert';

/// Calendar Screen - التقويم الهجري والميلادي مع إدارة المهام
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late ApiService _apiService;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  bool _isHijriCalendar = false; // false = ميلادي, true = هجري
  
  // Tasks and events
  Map<DateTime, List<TaskItem>> _tasks = {};
  List<TaskItem> _selectedDayTasks = [];
  
  // Settings
  int _notificationDaysBefore = 1;
  TimeOfDay _notificationTime = const TimeOfDay(hour: 9, minute: 0);
  bool _enableNotifications = true;
  
  bool _isLoading = false;
  
  // Notifications
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _apiService = Provider.of<AuthProvider>(context, listen: false).apiService;
      _loadSettings();
      _loadTasks();
      _loadHearings();
    });
  }

  Future<void> _initializeNotifications() async {
    try {
      // Initialize timezone
      tz.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Riyadh'));
      } catch (e) {
        // If timezone not found, use UTC as fallback
        debugPrint('Warning: Could not set timezone to Asia/Riyadh, using local: $e');
      }
      
      // Android initialization settings
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // iOS initialization settings (optional)
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      
      final initialized = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      
      debugPrint('Notifications initialized: $initialized');
      
      // Request permissions for Android
      final androidImplementation = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidImplementation != null) {
        // Request notification permission (Android 13+)
        final notificationGranted = await androidImplementation.requestNotificationsPermission();
        debugPrint('Notification permission granted: $notificationGranted');
        
        // Request exact alarm permission (Android 12+)
        final exactAlarmGranted = await androidImplementation.requestExactAlarmsPermission();
        debugPrint('Exact alarm permission granted: $exactAlarmGranted');
        
        if (notificationGranted == true) {
          // Test notification to verify setup
          await _notifications.show(
            999999,
            'الإشعارات مفعلة',
            exactAlarmGranted == true 
                ? 'تم تفعيل الإشعارات بنجاح' 
                : 'يرجى منح إذن الجدولة الدقيقة من إعدادات التطبيق',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'task_reminders',
                'تذكيرات المهام',
                channelDescription: 'إشعارات تذكير بالمهام والجلسات',
                importance: Importance.high,
                priority: Priority.high,
              ),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error initializing notifications: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ID=${response.id}, Payload=${response.payload}');
    
    if (mounted) {
      try {
        final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
        if (response.payload != null && response.payload!.isNotEmpty) {
          try {
            final payloadData = jsonDecode(response.payload!);
            notificationProvider.addNotification(AppNotification(
              id: 'local_${response.id}_${DateTime.now().millisecondsSinceEpoch}',
              title: payloadData['title'] ?? 'إشعار من التقويم',
              body: payloadData['body'] ?? payloadData['message'] ?? '',
              createdAt: DateTime.now(),
              type: 'calendar',
              data: payloadData,
            ));

            // Navigate to session detail if it's a session notification
            if (payloadData['type'] == 'session' && payloadData['hearing_id'] != null) {
              _navigateToSessionFromNotification(payloadData['hearing_id']);
            }
          } catch (e) {
            notificationProvider.addNotification(AppNotification(
              id: 'local_${response.id}_${DateTime.now().millisecondsSinceEpoch}',
              title: 'إشعار من التقويم',
              body: response.payload ?? '',
              createdAt: DateTime.now(),
              type: 'calendar',
            ));
          }
        } else {
          notificationProvider.addNotification(AppNotification(
            id: 'local_${response.id}_${DateTime.now().millisecondsSinceEpoch}',
            title: 'إشعار من التقويم',
            body: 'تم النقر على إشعار',
            createdAt: DateTime.now(),
            type: 'calendar',
          ));
        }
      } catch (e) {
        debugPrint('Error adding notification from tap: $e');
      }
    }
  }

  Future<void> _navigateToSessionFromNotification(int hearingId) async {
    try {
      final resp = await _apiService.getHearings();
      final results = resp is Map ? (resp['results'] ?? []) : (resp is List ? resp : []);
      for (final h in results) {
        if (h['id'] == hearingId) {
          final session = HearingModel.fromJson(h as Map<String, dynamic>);
          if (mounted) {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => SessionDetailScreen(session: session),
            ));
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Error navigating to session: $e');
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationDaysBefore = prefs.getInt('notification_days_before') ?? 1;
      _notificationTime = TimeOfDay(
        hour: prefs.getInt('notification_hour') ?? 9,
        minute: prefs.getInt('notification_minute') ?? 0,
      );
      _enableNotifications = prefs.getBool('enable_notifications') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('notification_days_before', _notificationDaysBefore);
    await prefs.setInt('notification_hour', _notificationTime.hour);
    await prefs.setInt('notification_minute', _notificationTime.minute);
    await prefs.setBool('enable_notifications', _enableNotifications);
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = prefs.getString('calendar_tasks');
    if (tasksJson != null) {
      final Map<String, dynamic> decoded = jsonDecode(tasksJson);
      final Map<DateTime, List<TaskItem>> loadedTasks = {};
      
      decoded.forEach((key, value) {
        final date = DateTime.parse(key);
        final normalizedDate = DateTime(date.year, date.month, date.day);
        loadedTasks[normalizedDate] = (value as List)
            .map((item) => TaskItem.fromJson(item))
            .toList();
      });
      
      setState(() {
        _tasks = loadedTasks;
        _updateSelectedDayTasks();
      });
      
      // Reschedule all notifications after loading tasks
      _rescheduleAllNotifications();
    }
  }

  Future<void> _rescheduleAllNotifications() async {
    if (!_enableNotifications) {
      debugPrint('Notifications are disabled, skipping reschedule');
      return;
    }
    
    try {
      debugPrint('Rescheduling all notifications...');
      // Cancel all existing notifications first
      await _notifications.cancelAll();
      debugPrint('Cancelled all existing notifications');
      
      // Schedule notifications for all tasks
      int taskCount = 0;
      for (var dateTasks in _tasks.values) {
        for (var task in dateTasks) {
          await _scheduleNotification(task);
          taskCount++;
        }
      }
      debugPrint('✅ Rescheduled notifications for $taskCount tasks');
    } catch (e, stackTrace) {
      debugPrint('❌ Error rescheduling notifications: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> encoded = {};
    
    _tasks.forEach((key, value) {
      encoded[key.toIso8601String()] = value.map((item) => item.toJson()).toList();
    });
    
    await prefs.setString('calendar_tasks', jsonEncode(encoded));
  }

  Future<void> _loadHearings() async {
    setState(() => _isLoading = true);
    try {
      final startDate = DateTime(_focusedDay.year, _focusedDay.month, 1);
      
      final response = await _apiService.getHearings();
      final results = response is Map ? (response['results'] ?? []) : (response is List ? response : []);
      for (var hearing in results) {
        final hearingDate = DateTime.tryParse(hearing['hearing_date'] ?? '');
        if (hearingDate != null) {
          final normalizedDate = DateTime(hearingDate.year, hearingDate.month, hearingDate.day);
          
          // Filter hearings for the current month only
          if (normalizedDate.year != startDate.year || normalizedDate.month != startDate.month) {
            continue;
          }

          final sessionType = hearing['session_type'] ?? 'upcoming';
          final isUpcoming = sessionType == 'upcoming';
          final caseNum = hearing['lawsuit_case_number'] ?? hearing['lawsuit']?['case_number'] ?? '';
          
          final task = TaskItem(
            id: 'hearing_${hearing['id']}',
            title: isUpcoming ? 'جلسة قادمة: $caseNum' : 'جلسة سابقة: $caseNum',
            description: hearing['requirements'] ?? hearing['notes'] ?? '',
            date: normalizedDate,
            time: hearing['hearing_time'] ?? '',
            type: TaskType.hearing,
            lawsuitId: hearing['lawsuit_id'],
            caseId: hearing['case_id'],
            color: isUpcoming ? const Color(0xFF3B82F6) : const Color(0xFFE65100),
          );
          
          if (!_tasks.containsKey(normalizedDate)) {
            _tasks[normalizedDate] = [];
          }
          // Check if hearing already exists
          if (!_tasks[normalizedDate]!.any((t) => t.id == task.id)) {
            _tasks[normalizedDate]!.add(task);
          }

          // Schedule notification for upcoming sessions
          if (isUpcoming && _enableNotifications) {
            await _scheduleSessionNotification(hearing);
          }
        }
      }
      setState(() {
        _updateSelectedDayTasks();
      });
    } catch (e) {
      debugPrint('Error loading hearings: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _scheduleSessionNotification(Map<String, dynamic> hearing) async {
    try {
      final hearingDate = DateTime.tryParse(hearing['hearing_date'] ?? '');
      if (hearingDate == null) return;
      final now = DateTime.now();
      final hearingId = hearing['id'] ?? 0;

      // Schedule 1h, 3h, and 1-day before notifications
      final offsets = [
        {'label': 'ساعة واحدة', 'duration': const Duration(hours: 1), 'idOffset': 0},
        {'label': '3 ساعات', 'duration': const Duration(hours: 3), 'idOffset': 1},
        {'label': 'يوم واحد', 'duration': const Duration(days: 1), 'idOffset': 2},
      ];

      for (final offset in offsets) {
        final scheduleTime = hearingDate.subtract(offset['duration'] as Duration);
        if (scheduleTime.isAfter(now)) {
          final notifId = (hearingId as int) * 10 + (offset['idOffset'] as int);
          final payload = jsonEncode({
            'type': 'session',
            'hearing_id': hearingId,
            'case_id': hearing['case_id'],
            'title': 'تذكير جلسة',
            'body': 'لديك جلسة بعد ${offset['label']}',
          });

          try {
            await _notifications.zonedSchedule(
              notifId,
              'تذكير بموعد الجلسة',
              'لديك جلسة بعد ${offset['label']} - ${hearing['requirements'] ?? ''}',
              tz.TZDateTime.from(scheduleTime, tz.local),
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  'session_reminders',
                  'تذكيرات الجلسات',
                  channelDescription: 'إشعارات تذكير قبل الجلسات',
                  importance: Importance.high,
                  priority: Priority.high,
                  icon: '@mipmap/ic_launcher',
                ),
              ),
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
              payload: payload,
              matchDateTimeComponents: null,
            );
          } catch (e) {
            debugPrint('Failed to schedule notification $notifId: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error scheduling session notification: $e');
    }
  }

  void _updateSelectedDayTasks() {
    final normalizedDate = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    _selectedDayTasks = _tasks[normalizedDate] ?? [];
  }

  List<TaskItem> _getTasksForDay(DateTime day) {
    final normalizedDate = DateTime(day.year, day.month, day.day);
    return _tasks[normalizedDate] ?? [];
  }

  String _getHijriDate(DateTime date) {
    final hijri = HijriCalendar.fromDate(date);
    return '${hijri.hDay} ${_getArabicHijriMonthName(hijri.hMonth)} ${hijri.hYear}';
  }

  String _getHijriMonthYear(DateTime date) {
    final hijri = HijriCalendar.fromDate(date);
    return '${_getArabicHijriMonthName(hijri.hMonth)} ${hijri.hYear}';
  }

  String _getArabicMonthName(int month) {
    final months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    return months[month - 1];
  }

  String _getArabicHijriMonthName(int hMonth) {
    // أسماء الأشهر الهجرية بالعربية
    final hijriMonths = [
      'محرم', 'صفر', 'ربيع الأول', 'ربيع الثاني', 'جمادى الأولى', 'جمادى الثانية',
      'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة'
    ];
    return hijriMonths[hMonth - 1];
  }

  String _getFormattedDate(DateTime date) {
    if (_isHijriCalendar) {
      return _getHijriDate(date);
    } else {
      return DateFormat('yyyy-MM-dd').format(date);
    }
  }

  // دالة مساعدة للتحويل من هجري إلى ميلادي (تقريبي)
  DateTime _hijriToGregorian(int hYear, int hMonth, int hDay) {
    // حساب تقريبي: السنة الهجرية = السنة الميلادية - 622 تقريباً
    // والشهر الهجري أقصر بحوالي 11 يوم
    final approxYear = hYear + 622;
    final approxMonth = hMonth;
    final approxDay = hDay;
    
    // استخدام تاريخ تقريبي ثم التحقق والتعديل
    DateTime result = DateTime(approxYear, approxMonth, approxDay);
    var checkHijri = HijriCalendar.fromDate(result);
    
    // تعديل حتى نحصل على التاريخ الصحيح
    int attempts = 0;
    while ((checkHijri.hYear != hYear || checkHijri.hMonth != hMonth || checkHijri.hDay != hDay) && attempts < 10) {
      final yearDiff = hYear - checkHijri.hYear;
      final monthDiff = hMonth - checkHijri.hMonth;
      final dayDiff = hDay - checkHijri.hDay;
      
      // حساب الفرق التقريبي بالأيام
      final daysDiff = yearDiff * 354 + monthDiff * 30 + dayDiff;
      result = result.add(Duration(days: daysDiff));
      
      checkHijri = HijriCalendar.fromDate(result);
      attempts++;
    }
    
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            _buildCalendarHeader(),
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: _buildCalendar(),
              ),
            ),
            _buildAddTaskButton(),
            Expanded(
              flex: 1,
              child: _buildTasksList(),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFF7F8FA),
      elevation: 0,
      automaticallyImplyLeading: false,
      title: const Text(
        'التقويم',
        style: TextStyle(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_calendar_outlined, color: Colors.black87),
          onPressed: () => _showSettingsDialog(),
        ),
        IconButton(
          icon: const Icon(Icons.archive_outlined, color: Colors.black87),
          onPressed: () => _showMonthlyArchive(),
        ),
      ],
    );
  }

  Widget _buildCalendarHeader() {
    String monthYear;
    if (_isHijriCalendar) {
      monthYear = _getHijriMonthYear(_focusedDay);
    } else {
      // استخدام اسم الشهر العربي
      monthYear = '${_getArabicMonthName(_focusedDay.month)} ${_focusedDay.year}';
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.black54),
            onPressed: () {
              setState(() {
                if (_isHijriCalendar) {
                  // للتقويم الهجري، نحتاج للتحويل أولاً
                  final hijri = HijriCalendar.fromDate(_focusedDay);
                  int newMonth = hijri.hMonth;
                  int newYear = hijri.hYear;
                  if (hijri.hMonth > 1) {
                    newMonth = hijri.hMonth - 1;
                  } else {
                    newMonth = 12;
                    newYear = hijri.hYear - 1;
                  }
                  _focusedDay = _hijriToGregorian(newYear, newMonth, 1);
                } else {
                  _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
                }
              });
              _loadHearings();
            },
          ),
          Text(
            monthYear,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isHijriCalendar = !_isHijriCalendar;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isHijriCalendar ? const Color(0xFFD4A940) : Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _isHijriCalendar ? 'هجري' : 'ميلادي',
                    style: TextStyle(
                      fontSize: 12,
                      color: _isHijriCalendar ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.black54),
                onPressed: () {
                  setState(() {
                    if (_isHijriCalendar) {
                      // للتقويم الهجري، نحتاج للتحويل أولاً
                      final hijri = HijriCalendar.fromDate(_focusedDay);
                      int newMonth = hijri.hMonth;
                      int newYear = hijri.hYear;
                      if (hijri.hMonth < 12) {
                        newMonth = hijri.hMonth + 1;
                      } else {
                        newMonth = 1;
                        newYear = hijri.hYear + 1;
                      }
                      _focusedDay = _hijriToGregorian(newYear, newMonth, 1);
                    } else {
                      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
                    }
                  });
                  _loadHearings();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          _buildWeekDaysHeader(),
          _buildCalendarGrid(),
        ],
      ),
    );
  }

  Widget _buildWeekDaysHeader() {
    final weekDays = ['السبت', 'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: weekDays.map((day) => SizedBox(
          width: 42,
          child: Text(
            day,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    if (_isHijriCalendar) {
      return _buildHijriCalendarGrid();
    } else {
      return _buildGregorianCalendarGrid();
    }
  }

  Widget _buildGregorianCalendarGrid() {
    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final lastDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
    
    // الترتيب من اليمين لليسار: السبت، الأحد، ..., الجمعة
    // في دارت: 1=الاثنين، ..., 6=السبت، 7=الأحد
    // نريد: السبت=0، الأحد=1، الاثنين=2، الثلاثاء=3، الأربعاء=4، الخميس=5، الجمعة=6
    final firstWeekday = (firstDayOfMonth.weekday % 7 + 1) % 7;
    
    final daysInMonth = lastDayOfMonth.day;
    
    // Calculate number of rows needed
    // We need: firstWeekday empty cells + daysInMonth days
    // Total cells = firstWeekday + daysInMonth
    // Number of rows = ceil(totalCells / 7)
    final totalCells = firstWeekday + daysInMonth;
    final numberOfRows = (totalCells / 7).ceil();
    final actualTotalCells = numberOfRows * 7;
    
    List<Widget> rows = [];
    
    // Build all rows
    for (int row = 0; row < numberOfRows; row++) {
      List<Widget> currentRow = [];
      
      // بناء الصف
      for (int col = 0; col < 7; col++) {
        final cellIndex = row * 7 + col;
        final dayNumber = cellIndex - firstWeekday + 1;
        final isCurrentMonth = dayNumber > 0 && dayNumber <= daysInMonth;
        final date = isCurrentMonth 
            ? DateTime(_focusedDay.year, _focusedDay.month, dayNumber)
            : null;
        
        currentRow.add(_buildDayCell(dayNumber, isCurrentMonth, date));
      }
      
      rows.add(Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: currentRow,
      ));
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 2, top: 2),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: rows,
      ),
    );
  }

  Widget _buildHijriCalendarGrid() {
    final hijri = HijriCalendar.fromDate(_focusedDay);
    final daysInMonth = hijri.lengthOfMonth;
    
    // الحصول على اليوم الأول من الشهر الهجري
    final firstDayDate = _hijriToGregorian(hijri.hYear, hijri.hMonth, 1);
    
    // الترتيب من اليمين لليسار: السبت، الأحد، ..., الجمعة
    final firstWeekday = (firstDayDate.weekday % 7 + 1) % 7;
    
    // Calculate number of rows needed
    final totalCells = firstWeekday + daysInMonth;
    final numberOfRows = (totalCells / 7).ceil();
    
    List<Widget> rows = [];
    
    // Build all rows
    for (int row = 0; row < numberOfRows; row++) {
      List<Widget> currentRow = [];
      
      // بناء الصف
      for (int col = 0; col < 7; col++) {
        final cellIndex = row * 7 + col;
        final dayNumber = cellIndex - firstWeekday + 1;
        final isCurrentMonth = dayNumber > 0 && dayNumber <= daysInMonth;
        DateTime? date;
        
        if (isCurrentMonth) {
          date = _hijriToGregorian(hijri.hYear, hijri.hMonth, dayNumber);
        }
        
        currentRow.add(_buildDayCell(dayNumber, isCurrentMonth, date));
      }
      
      rows.add(Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: currentRow,
      ));
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 2, top: 2),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: rows,
      ),
    );
  }

  Widget _buildDayCell(int dayNumber, bool isCurrentMonth, DateTime? date) {
    // Only show content if this is a valid day in the current month
    final shouldShow = isCurrentMonth && dayNumber > 0 && date != null;
    
    final isToday = shouldShow && 
        date!.year == DateTime.now().year &&
        date.month == DateTime.now().month &&
        date.day == DateTime.now().day;
    
    final isSelected = shouldShow &&
        date!.year == _selectedDay.year &&
        date.month == _selectedDay.month &&
        date.day == _selectedDay.day;
    
    final tasks = shouldShow ? _getTasksForDay(date!) : [];
    final hasTasks = tasks.isNotEmpty;
    final hasHearing = tasks.any((t) => t.type == TaskType.hearing);
    final hasAppointment = tasks.any((t) => t.type == TaskType.appointment);
    final hasTask = tasks.any((t) => t.type == TaskType.task);
    
    return GestureDetector(
      onTap: shouldShow ? () => _onDaySelected(date!) : null,
      onLongPress: shouldShow ? () => _showAddTaskDialog(date!) : null,
      child: Container(
        width: 42,
        height: 42,
        margin: const EdgeInsets.symmetric(vertical: 1),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFFD4A940)
              : isToday 
                  ? const Color(0xFFD4A940).withOpacity(0.2)
                  : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: shouldShow
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$dayNumber',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected 
                          ? Colors.white
                          : Colors.black87,
                      fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                  if (hasTasks)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasHearing)
                          Container(
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.only(top: 2, right: 1),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE65100),
                              shape: BoxShape.circle,
                            ),
                          ),
                        if (hasAppointment)
                          Container(
                            width: 5,
                            height: 5,
                            margin: EdgeInsets.only(top: 2, right: hasHearing ? 1.0 : 0.0, left: hasHearing ? 0.0 : 1.0),
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                        if (hasTask)
                          Container(
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.only(top: 2, left: 1),
                            decoration: const BoxDecoration(
                              color: Color(0xFF4CAF50),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                ],
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  void _onDaySelected(DateTime selectedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _updateSelectedDayTasks();
    });
    
    // If there's a hearing, offer to navigate to case archive
    final hearings = _selectedDayTasks.where((t) => t.type == TaskType.hearing).toList();
    if (hearings.isNotEmpty && hearings.first.lawsuitId != null) {
      _showHearingOptionsDialog(hearings.first);
    }
  }

  Widget _buildAddTaskButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _showAddTaskDialog(_selectedDay),
          icon: const Icon(Icons.add, color: Colors.white, size: 20),
          label: const Text(
            'Add Task',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4A940),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildTasksList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFD4A940)));
    }
    
    if (_selectedDayTasks.isEmpty) {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.event_available_outlined,
                size: 80,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                'No tasks for this day',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _getFormattedDate(_selectedDay),
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _selectedDayTasks.length,
      itemBuilder: (context, index) {
        final task = _selectedDayTasks[index];
        return _buildTaskCard(task);
      },
    );
  }

  Widget _buildTaskCard(TaskItem task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 12,
          height: 50,
          decoration: BoxDecoration(
            color: task.color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        title: Text(
          task.title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description.isNotEmpty)
              Text(
                task.description,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (task.time.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      task.time,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (task.type == TaskType.hearing && (task.caseId != null || task.lawsuitId != null))
              IconButton(
                icon: const Icon(Icons.folder_open, color: Color(0xFFD4A940)),
                onPressed: () => _navigateToCase(task),
                tooltip: 'عرض القضية',
              ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Color(0xFFD4A940)),
              onPressed: () => _showEditTaskDialog(task),
              tooltip: 'تعديل المهمة',
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red[300]),
              onPressed: () => _deleteTask(task),
              tooltip: 'حذف المهمة',
            ),
          ],
        ),
      ),
    );
  }


  void _showAddTaskDialog(DateTime date) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final timeController = TextEditingController();
    TaskType selectedType = TaskType.task;
    int? selectedCaseId;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'إضافة مهمة جديدة',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        DateFormat('yyyy-MM-dd').format(date),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getFormattedDate(date),
                    style: TextStyle(
                      color: const Color(0xFFD4A940),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Task Type Selection
                  const Text(
                    'نوع المهمة',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildTypeChip(
                        'مهمة',
                        TaskType.task,
                        selectedType,
                        (type) => setModalState(() => selectedType = type),
                        Colors.green,
                      ),
                      const SizedBox(width: 8),
                      _buildTypeChip(
                        'موعد',
                        TaskType.appointment,
                        selectedType,
                        (type) => setModalState(() => selectedType = type),
                        Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      _buildTypeChip(
                        'جلسة',
                        TaskType.hearing,
                        selectedType,
                        (type) => setModalState(() => selectedType = type),
                        const Color(0xFFE65100),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Title
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'العنوان',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD4A940), width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Description
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'الوصف',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD4A940), width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Time
                  TextField(
                    controller: timeController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'الوقت',
                      suffixIcon: const Icon(Icons.access_time),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD4A940), width: 2),
                      ),
                    ),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null) {
                        timeController.text = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Link to a case (for hearing type)
                  if (selectedType == TaskType.hearing)
                    _buildCaseLinkDropdown(
                      selectedCaseId: selectedCaseId,
                      onChanged: (value) {
                        setModalState(() => selectedCaseId = value);
                      },
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (titleController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('يرجى إدخال عنوان المهمة')),
                          );
                          return;
                        }

                        final navigator = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);

                        int? resolvedLawsuitId;
                        int? backendHearingId;
                        if (selectedType == TaskType.hearing && selectedCaseId != null) {
                          resolvedLawsuitId = await _resolveFirstLawsuitForCase(selectedCaseId!);
                          if (resolvedLawsuitId == null) {
                            messenger.showSnackBar(const SnackBar(
                              content: Text('لا توجد دعوى ضمن القضية المختارة لربط الجلسة بها. أضف دعوى للقضية أولاً.'),
                              backgroundColor: Colors.orange,
                            ));
                            return;
                          }
                          try {
                            final created = await _apiService.createHearing({
                              'lawsuit_id': resolvedLawsuitId,
                              'hearing_date': DateFormat('yyyy-MM-dd').format(date),
                              if (timeController.text.isNotEmpty)
                                'hearing_time': timeController.text.length == 5
                                    ? '${timeController.text}:00'
                                    : timeController.text,
                              'notes': descriptionController.text.isEmpty
                                  ? titleController.text
                                  : descriptionController.text,
                              'hearing_type': 'main',
                            });
                            backendHearingId = created['id'] as int?;
                          } catch (e) {
                            messenger.showSnackBar(SnackBar(
                              content: Text('تعذر حفظ الجلسة في الخادم: $e'),
                              backgroundColor: Colors.red,
                            ));
                            return;
                          }
                        }

                        final task = TaskItem(
                          id: backendHearingId != null
                              ? 'hearing_$backendHearingId'
                              : DateTime.now().millisecondsSinceEpoch.toString(),
                          title: titleController.text,
                          description: descriptionController.text,
                          date: date,
                          time: timeController.text,
                          type: selectedType,
                          lawsuitId: resolvedLawsuitId,
                          caseId: selectedCaseId,
                          color: selectedType == TaskType.hearing
                              ? const Color(0xFFE65100)
                              : selectedType == TaskType.appointment
                                  ? Colors.blue
                                  : Colors.green,
                        );
                        
                        await _addTask(task);
                        navigator.pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4A940),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'حفظ المهمة',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTypeChip(
    String label,
    TaskType type,
    TaskType selectedType,
    Function(TaskType) onSelect,
    Color color,
  ) {
    final isSelected = type == selectedType;
    return GestureDetector(
      onTap: () => onSelect(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Future<void> _addTask(TaskItem task) async {
    final normalizedDate = DateTime(task.date.year, task.date.month, task.date.day);
    
    setState(() {
      if (!_tasks.containsKey(normalizedDate)) {
        _tasks[normalizedDate] = [];
      }
      _tasks[normalizedDate]!.add(task);
      _updateSelectedDayTasks();
    });
    
    await _saveTasks();
    await _scheduleNotification(task);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تمت إضافة المهمة بنجاح'),
          backgroundColor: Color(0xFFD4A940),
        ),
      );
    }
  }

  void _deleteTask(TaskItem task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المهمة'),
        content: Text('هل أنت متأكد من حذف "${task.title}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              // Cancel notifications for this task
              await _notifications.cancel(task.id.hashCode); // Reminder notification
              await _notifications.cancel(task.id.hashCode + 10000); // Task time notification
              
              final normalizedDate = DateTime(task.date.year, task.date.month, task.date.day);
              setState(() {
                _tasks[normalizedDate]?.removeWhere((t) => t.id == task.id);
                _updateSelectedDayTasks();
              });
              _saveTasks();
              Navigator.pop(context);
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم حذف المهمة'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditTaskDialog(TaskItem task) {
    final titleController = TextEditingController(text: task.title);
    final descriptionController = TextEditingController(text: task.description);
    final timeController = TextEditingController(text: task.time);
    TaskType selectedType = task.type;
    int? selectedCaseId = task.caseId;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'تعديل المهمة',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        DateFormat('yyyy-MM-dd').format(task.date),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getFormattedDate(task.date),
                    style: TextStyle(
                      color: const Color(0xFFD4A940),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Task Type Selection
                  const Text(
                    'نوع المهمة',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildTypeChip(
                        'مهمة',
                        TaskType.task,
                        selectedType,
                        (type) => setModalState(() => selectedType = type),
                        Colors.green,
                      ),
                      const SizedBox(width: 8),
                      _buildTypeChip(
                        'موعد',
                        TaskType.appointment,
                        selectedType,
                        (type) => setModalState(() => selectedType = type),
                        Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      _buildTypeChip(
                        'جلسة',
                        TaskType.hearing,
                        selectedType,
                        (type) => setModalState(() => selectedType = type),
                        const Color(0xFFE65100),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Title
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'العنوان',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD4A940), width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Description
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'الوصف',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD4A940), width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Time
                  TextField(
                    controller: timeController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'الوقت',
                      suffixIcon: const Icon(Icons.access_time),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD4A940), width: 2),
                      ),
                    ),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: task.time.isNotEmpty
                            ? TimeOfDay(
                                hour: int.tryParse(task.time.split(':')[0]) ?? 9,
                                minute: int.tryParse(task.time.split(':')[1]) ?? 0,
                              )
                            : TimeOfDay.now(),
                      );
                      if (time != null) {
                        timeController.text = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Link to a case (for hearing type)
                  if (selectedType == TaskType.hearing)
                    _buildCaseLinkDropdown(
                      selectedCaseId: selectedCaseId,
                      onChanged: (value) {
                        setModalState(() => selectedCaseId = value);
                      },
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (titleController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('يرجى إدخال عنوان المهمة')),
                          );
                          return;
                        }
                        
                        _updateTask(
                          task,
                          titleController.text,
                          descriptionController.text,
                          timeController.text,
                          selectedType,
                          selectedCaseId,
                        );
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4A940),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'حفظ التعديلات',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _updateTask(
    TaskItem oldTask,
    String newTitle,
    String newDescription,
    String newTime,
    TaskType newType,
    int? newCaseId,
  ) async {
    // Cancel old notifications
    await _notifications.cancel(oldTask.id.hashCode);
    await _notifications.cancel(oldTask.id.hashCode + 10000);
    
    final normalizedDate = DateTime(oldTask.date.year, oldTask.date.month, oldTask.date.day);

    // If the case link changed for a hearing, try to resolve a new lawsuit id.
    int? newLawsuitId = oldTask.lawsuitId;
    if (newType == TaskType.hearing && newCaseId != null && newCaseId != oldTask.caseId) {
      newLawsuitId = await _resolveFirstLawsuitForCase(newCaseId);
    }

    final updatedTask = TaskItem(
      id: oldTask.id,
      title: newTitle,
      description: newDescription,
      date: oldTask.date,
      time: newTime,
      type: newType,
      lawsuitId: newLawsuitId,
      caseId: newCaseId,
      color: newType == TaskType.hearing
          ? const Color(0xFFE65100)
          : newType == TaskType.appointment
              ? Colors.blue
              : Colors.green,
    );
    
    setState(() {
      final taskIndex = _tasks[normalizedDate]?.indexWhere((t) => t.id == oldTask.id);
      if (taskIndex != null && taskIndex >= 0) {
        _tasks[normalizedDate]![taskIndex] = updatedTask;
        _updateSelectedDayTasks();
      }
    });
    
    _saveTasks();
    
    // Schedule new notifications
    await _scheduleNotification(updatedTask);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تحديث المهمة بنجاح'),
        backgroundColor: Color(0xFFD4A940),
      ),
    );
  }

  Future<void> _scheduleNotification(TaskItem task) async {
    if (!_enableNotifications) {
      debugPrint('Notifications are disabled');
      return;
    }
    
    try {
      debugPrint('Scheduling notification for task: ${task.title}, Date: ${task.date}, Time: ${task.time}');
      
      // Helper function to schedule with fallback
      Future<void> scheduleWithFallback({
        required int id,
        required String title,
        required String body,
        required tz.TZDateTime scheduledTime,
        String? payload,
      }) async {
        try {
          // Try exact scheduling first
          await _notifications.zonedSchedule(
            id,
            title,
            body,
            scheduledTime,
            NotificationDetails(
              android: const AndroidNotificationDetails(
                'task_reminders',
                'تذكيرات المهام',
                channelDescription: 'إشعارات تذكير بالمهام والجلسات',
                importance: Importance.max,
                priority: Priority.high,
                showWhen: true,
                playSound: true,
                enableVibration: true,
                fullScreenIntent: true,
                icon: '@mipmap/ic_launcher',
              ),
              iOS: const DarwinNotificationDetails(),
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
            payload: payload,
          );
          debugPrint('✅ Scheduled with exact mode (ID: $id)');
        } catch (e) {
          // If exact fails, try inexact
          if (e.toString().contains('exact_alarms_not_permitted')) {
            debugPrint('⚠️ Exact alarm not permitted, using inexact mode');
            try {
              await _notifications.zonedSchedule(
                id,
                title,
                body,
                scheduledTime,
                NotificationDetails(
                  android: const AndroidNotificationDetails(
                    'task_reminders',
                    'تذكيرات المهام',
                    channelDescription: 'إشعارات تذكير بالمهام والجلسات',
                    importance: Importance.max,
                    priority: Priority.high,
                    showWhen: true,
                    playSound: true,
                    enableVibration: true,
                    fullScreenIntent: true,
                    icon: '@mipmap/ic_launcher',
                  ),
                  iOS: const DarwinNotificationDetails(),
                ),
                androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
                uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
                payload: payload,
              );
              debugPrint('✅ Scheduled with inexact mode (ID: $id)');
            } catch (e2) {
              debugPrint('❌ Failed to schedule with inexact mode: $e2');
              rethrow;
            }
          } else {
            rethrow;
          }
        }
      }
      
      // Schedule reminder notification (before the task)
      if (_notificationDaysBefore >= 0) {
        final reminderDate = task.date.subtract(Duration(days: _notificationDaysBefore));
        final reminderTime = DateTime(
          reminderDate.year,
          reminderDate.month,
          reminderDate.day,
          _notificationTime.hour,
          _notificationTime.minute,
        );
        
        debugPrint('Reminder time calculated: $reminderTime, Now: ${DateTime.now()}');
        
        if (reminderTime.isAfter(DateTime.now())) {
          final reminderId = task.id.hashCode;
          final scheduledTime = tz.TZDateTime.from(reminderTime, tz.local);
          
          final reminderPayload = jsonEncode({
            'title': 'تذكير: ${task.title}',
            'body': task.description.isNotEmpty 
                ? task.description 
                : '${task.type == TaskType.hearing ? 'جلسة' : task.type == TaskType.appointment ? 'موعد' : 'مهمة'} مقررة بعد $_notificationDaysBefore ${_notificationDaysBefore == 1 ? 'يوم' : _notificationDaysBefore == 0 ? 'اليوم' : 'أيام'}',
            'task_id': task.id,
            'task_date': task.date.toIso8601String(),
            'type': 'calendar_reminder',
          });
          
          await scheduleWithFallback(
            id: reminderId,
            title: 'تذكير: ${task.title}',
            body: task.description.isNotEmpty 
                ? task.description 
                : '${task.type == TaskType.hearing ? 'جلسة' : task.type == TaskType.appointment ? 'موعد' : 'مهمة'} مقررة بعد $_notificationDaysBefore ${_notificationDaysBefore == 1 ? 'يوم' : _notificationDaysBefore == 0 ? 'اليوم' : 'أيام'}',
            scheduledTime: scheduledTime,
            payload: reminderPayload,
          );
          debugPrint('✅ Reminder scheduled for "${task.title}" at $scheduledTime (ID: $reminderId)');
          
          // Add to NotificationProvider
          if (mounted) {
            try {
              final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
              await notificationProvider.addNotification(AppNotification(
                id: 'calendar_reminder_$reminderId',
                title: 'تذكير: ${task.title}',
                body: task.description.isNotEmpty 
                    ? task.description 
                    : '${task.type == TaskType.hearing ? 'جلسة' : task.type == TaskType.appointment ? 'موعد' : 'مهمة'} مقررة بعد $_notificationDaysBefore ${_notificationDaysBefore == 1 ? 'يوم' : _notificationDaysBefore == 0 ? 'اليوم' : 'أيام'}',
                createdAt: DateTime.now(),
                type: 'calendar',
                data: {
                  'task_id': task.id,
                  'task_date': task.date.toIso8601String(),
                  'screen': 'calendar',
                },
              ));
            } catch (e) {
              debugPrint('Error adding notification to provider: $e');
            }
          }
        } else {
          debugPrint('⚠️ Reminder time is in the past, skipping: $reminderTime');
        }
      }
      
      // Schedule notification at task time (if time is specified)
      if (task.time.isNotEmpty) {
        final timeParts = task.time.split(':');
        if (timeParts.length == 2) {
          final hour = int.tryParse(timeParts[0]);
          final minute = int.tryParse(timeParts[1]);
          
          if (hour != null && minute != null && hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
            final taskDateTime = DateTime(
              task.date.year,
              task.date.month,
              task.date.day,
              hour,
              minute,
            );
            
            debugPrint('Task time calculated: $taskDateTime, Now: ${DateTime.now()}');
            
            // Schedule notification even if it's very soon (for testing)
            final scheduledTime = tz.TZDateTime.from(taskDateTime, tz.local);
            
            if (taskDateTime.isAfter(DateTime.now().subtract(const Duration(minutes: 1)))) {
              final taskId = task.id.hashCode + 10000; // Different ID to avoid conflicts
              
              final taskPayload = jsonEncode({
                'title': task.title,
                'body': task.description.isNotEmpty 
                    ? task.description 
                    : 'حان وقت ${task.type == TaskType.hearing ? 'الجلسة' : task.type == TaskType.appointment ? 'الموعد' : 'المهمة'}',
                'task_id': task.id,
                'task_date': task.date.toIso8601String(),
                'task_time': task.time,
                'type': 'calendar_task',
              });
              
              await scheduleWithFallback(
                id: taskId,
                title: task.title,
                body: task.description.isNotEmpty 
                    ? task.description 
                    : 'حان وقت ${task.type == TaskType.hearing ? 'الجلسة' : task.type == TaskType.appointment ? 'الموعد' : 'المهمة'}',
                scheduledTime: scheduledTime,
                payload: taskPayload,
              );
              debugPrint('✅ Task notification scheduled for "${task.title}" at $scheduledTime (ID: $taskId)');
              
              // Add to NotificationProvider
              if (mounted) {
                try {
                  final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
                  await notificationProvider.addNotification(AppNotification(
                    id: 'calendar_task_$taskId',
                    title: task.title,
                    body: task.description.isNotEmpty 
                        ? task.description 
                        : 'حان وقت ${task.type == TaskType.hearing ? 'الجلسة' : task.type == TaskType.appointment ? 'الموعد' : 'المهمة'}',
                    createdAt: DateTime.now(),
                    type: 'calendar',
                    data: {
                      'task_id': task.id,
                      'task_date': task.date.toIso8601String(),
                      'task_time': task.time,
                      'screen': 'calendar',
                    },
                  ));
                } catch (e) {
                  debugPrint('Error adding notification to provider: $e');
                }
              }
            } else {
              debugPrint('⚠️ Task time is in the past, skipping: $taskDateTime');
            }
          } else {
            debugPrint('⚠️ Invalid time format: ${task.time}');
          }
        } else {
          debugPrint('⚠️ Time format error: ${task.time}');
        }
      } else {
        debugPrint('⚠️ No time specified for task: ${task.title}');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error scheduling notification: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  void _showSettingsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'إعدادات التنبيهات',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Enable Notifications
                SwitchListTile(
                  title: const Text('تفعيل التنبيهات'),
                  value: _enableNotifications,
                  activeColor: const Color(0xFFD4A940),
                  onChanged: (value) {
                    setModalState(() => _enableNotifications = value);
                    setState(() {});
                    _saveSettings();
                  },
                ),
                
                const Divider(),
                
                // Days Before
                ListTile(
                  title: const Text('التنبيه قبل الموعد بـ'),
                  trailing: DropdownButton<int>(
                    value: _notificationDaysBefore,
                    items: [1, 2, 3, 5, 7].map((days) => DropdownMenuItem(
                      value: days,
                      child: Text('$days ${days == 1 ? 'يوم' : 'أيام'}'),
                    )).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() => _notificationDaysBefore = value);
                        setState(() {});
                        _saveSettings();
                      }
                    },
                  ),
                ),
                
                // Notification Time
                ListTile(
                  title: const Text('وقت التنبيه'),
                  trailing: GestureDetector(
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _notificationTime,
                      );
                      if (time != null) {
                        setModalState(() => _notificationTime = time);
                        setState(() {});
                        _saveSettings();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_notificationTime.hour.toString().padLeft(2, '0')}:${_notificationTime.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showMonthlyArchive() {
    final monthTasks = <TaskItem>[];
    final startOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final endOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
    
    _tasks.forEach((date, tasks) {
      if (date.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
          date.isBefore(endOfMonth.add(const Duration(days: 1)))) {
        monthTasks.addAll(tasks);
      }
    });
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'أرشيف ${_isHijriCalendar ? _getHijriMonthYear(_focusedDay) : '${_getArabicMonthName(_focusedDay.month)} ${_focusedDay.year}'}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${monthTasks.length} مهمة',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: monthTasks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 64,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'لا توجد مهام لهذا الشهر',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: monthTasks.length,
                          itemBuilder: (context, index) {
                            final task = monthTasks[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Container(
                                  width: 8,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: task.color,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                title: Text(
                                  task.title,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  '${DateFormat('dd/MM').format(task.date)} - ${task.time.isNotEmpty ? task.time : 'طوال اليوم'}',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                trailing: Icon(
                                  task.type == TaskType.hearing
                                      ? Icons.gavel
                                      : task.type == TaskType.appointment
                                          ? Icons.event
                                          : Icons.task_alt,
                                  color: task.color,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showHearingOptionsDialog(TaskItem hearing) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(hearing.title),
        content: Text('${_getFormattedDate(hearing.date)}\n${hearing.time.isNotEmpty ? 'الوقت: ${hearing.time}' : ''}'),
        actions: [
          if (hearing.caseId != null || hearing.lawsuitId != null)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _navigateToCase(hearing);
              },
              icon: const Icon(Icons.folder_open),
              label: const Text('عرض القضية'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Widget _buildCaseLinkDropdown({
    required int? selectedCaseId,
    required ValueChanged<int?> onChanged,
  }) {
    return FutureBuilder<dynamic>(
      future: _apiService.getCases(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Center(
              child: SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'خطأ في تحميل القضايا',
              style: TextStyle(color: Colors.red[400], fontSize: 13),
            ),
          );
        }

        List cases = [];
        final data = snapshot.data;
        if (data is List) {
          cases = data;
        } else if (data is Map) {
          if (data.containsKey('results')) {
            cases = data['results'] as List? ?? [];
          } else if (data.containsKey('data')) {
            final inner = data['data'];
            if (inner is Map && inner.containsKey('results')) {
              cases = inner['results'] as List? ?? [];
            } else if (inner is List) {
              cases = inner;
            }
          }
        }

        final validId = cases.any((c) => c['id'] == selectedCaseId)
            ? selectedCaseId
            : null;

        return DropdownButtonFormField<int>(
          value: validId,
          decoration: InputDecoration(
            labelText: 'ربط بقضية',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          items: [
            const DropdownMenuItem<int>(
              value: null,
              child: Text('بدون ربط'),
            ),
            ...cases.map((c) => DropdownMenuItem<int>(
              value: c['id'] as int,
              child: Text(
                '${c['case_number'] ?? 'غير معروف'}${c['subject'] != null ? ' - ${c['subject']}' : ''}',
                overflow: TextOverflow.ellipsis,
              ),
            )),
          ],
          onChanged: onChanged,
          isExpanded: true,
        );
      },
    );
  }

  /// Resolve the first (non-appeal) lawsuit under a case so a backend Hearing
  /// can be attached to it. Returns null if the case has no lawsuits yet.
  Future<int?> _resolveFirstLawsuitForCase(int caseId) async {
    try {
      final resp = await _apiService.getLawsuits(queryParams: {
        'case': caseId.toString(),
      });
      List list = [];
      if (resp is List) {
        list = resp;
      } else if (resp is Map) {
        list = (resp['results'] as List?) ?? (resp['data'] as List?) ?? [];
      }
      if (list.isEmpty) return null;
      return list.first['id'] as int?;
    } catch (_) {
      return null;
    }
  }

  void _navigateToCase(TaskItem task) {
    if (task.caseId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CaseDetailScreen(caseId: task.caseId!),
        ),
      );
    } else if (task.lawsuitId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LawsuitDetailScreen(lawsuitId: task.lawsuitId!),
        ),
      );
    }
  }
}

// Task Item Model
enum TaskType { task, appointment, hearing }

class TaskItem {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final String time;
  final TaskType type;
  final int? lawsuitId;
  final int? caseId;
  final Color color;

  TaskItem({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.time,
    required this.type,
    this.lawsuitId,
    this.caseId,
    required this.color,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'time': time,
      'type': type.index,
      'lawsuitId': lawsuitId,
      'caseId': caseId,
      'color': color.value,
    };
  }

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      date: DateTime.parse(json['date']),
      time: json['time'],
      type: TaskType.values[json['type']],
      lawsuitId: json['lawsuitId'],
      caseId: json['caseId'],
      color: Color(json['color']),
    );
  }
}

// Calendar Format enum
enum CalendarFormat { month, twoWeeks, week }
