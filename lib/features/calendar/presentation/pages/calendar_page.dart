import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:trivora_provider/core/providers/auth_provider.dart';
import 'package:trivora_provider/core/services/firestore_bookings_service.dart';

/// Calendar Page - Clean and optimized calendar view for bookings
class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  DateTime _selectedDate = DateTime.now();
  DateTime _displayMonth = DateTime.now();
  String? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authStateProvider).valueOrNull;
    if (authUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to view calendar')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
      ),
      body: Column(
        children: [
          // Status Filter
          _buildStatusFilter(),
          // Calendar View
          Expanded(
            child: _buildCalendarView(authUser.uid),
          ),
          // Selected Date Bookings
          _buildSelectedDateBookings(authUser.uid),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    // Responsive padding
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 800;
    final padding = isSmallScreen ? 12.0 : 16.0;
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding * 0.75),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('All', null),
            SizedBox(width: isSmallScreen ? 6 : 8),
            _buildFilterChip('Accepted', 'accepted'),
            SizedBox(width: isSmallScreen ? 6 : 8),
            _buildFilterChip('Pending', 'pending'),
            SizedBox(width: isSmallScreen ? 6 : 8),
            _buildFilterChip('In-Progress', 'in_progress'),
            SizedBox(width: isSmallScreen ? 6 : 8),
            _buildFilterChip('Completed', 'completed'),
            SizedBox(width: isSmallScreen ? 6 : 8),
            _buildFilterChip('Cancelled', 'cancelled'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String? status) {
    final isSelected = _statusFilter == status;
    // Responsive font size
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 800;
    final fontSize = isSmallScreen ? 12.0 : 13.0;
    final padding = isSmallScreen 
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
    
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: fontSize)),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _statusFilter = status;
        });
      },
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      checkmarkColor: Theme.of(context).colorScheme.primary,
      padding: padding,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildCalendarView(String userId) {
    final firestoreService = ref.read(firestoreBookingsServiceProvider);
    
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: firestoreService.getBookingsStream(userId, status: _statusFilter),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final allBookings = snapshot.data ?? [];
        final bookingsByDate = _groupBookingsByDate(allBookings);

        return Column(
          children: [
            _buildMonthHeader(),
            Expanded(
              child: _buildCalendarGrid(bookingsByDate),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMonthHeader() {
    final monthYear = DateFormat('MMMM yyyy').format(_displayMonth);
    // Responsive sizing
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 800;
    final padding = isSmallScreen ? 12.0 : 16.0;
    final iconSize = isSmallScreen ? 20.0 : 24.0;
    final fontSize = isSmallScreen ? 14.0 : 16.0;
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding * 0.75),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, size: iconSize),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              setState(() {
                _displayMonth = DateTime(_displayMonth.year, _displayMonth.month - 1);
              });
            },
          ),
          Text(
            monthYear,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: isSmallScreen ? 16 : 18,
                ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 8 : 12,
                    vertical: isSmallScreen ? 4 : 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  setState(() {
                    _displayMonth = DateTime.now();
                    _selectedDate = DateTime.now();
                  });
                },
                child: Text('Today', style: TextStyle(fontSize: fontSize)),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, size: iconSize),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  setState(() {
                    _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + 1);
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(Map<DateTime, List<Map<String, dynamic>>> bookingsByDate) {
    final firstDay = DateTime(_displayMonth.year, _displayMonth.month, 1);
    final lastDay = DateTime(_displayMonth.year, _displayMonth.month + 1, 0);
    final firstDayWeekday = firstDay.weekday;
    final daysInMonth = lastDay.day;

    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    
    // Responsive sizing based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 800;
    final isLaptopScreen = screenWidth >= 1200;
    
    // Adjust sizes based on screen size
    final cellAspectRatio = isSmallScreen ? 1.2 : (isLaptopScreen ? 1.0 : 1.1);
    final cellSpacing = isSmallScreen ? 2.0 : 4.0;
    final weekdayFontSize = isSmallScreen ? 11.0 : 12.0;
    final padding = isSmallScreen ? 12.0 : 16.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding * 0.5),
      child: Column(
        children: [
          // Weekday headers
          Row(
            children: weekdays.map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                      fontSize: weekdayFontSize,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: isSmallScreen ? 4 : 8),
          // Calendar grid with scrollbar
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: GridView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: cellAspectRatio,
                  crossAxisSpacing: cellSpacing,
                  mainAxisSpacing: cellSpacing,
                ),
                itemCount: firstDayWeekday - 1 + daysInMonth,
                itemBuilder: (context, index) {
                if (index < firstDayWeekday - 1) {
                  return const SizedBox.shrink();
                }

                final day = index - (firstDayWeekday - 1) + 1;
                final cellDate = DateTime(_displayMonth.year, _displayMonth.month, day);
                final isToday = _isSameDay(cellDate, DateTime.now());
                final isSelected = _isSameDay(cellDate, _selectedDate);
                final dayBookings = bookingsByDate[cellDate] ?? [];

                return _buildCalendarCell(
                  cellDate,
                  day,
                  isToday,
                  isSelected,
                  dayBookings,
                );
              },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCell(
    DateTime date,
    int day,
    bool isToday,
    bool isSelected,
    List<Map<String, dynamic>> bookings,
  ) {
    // Responsive sizing
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 800;
    final dateFontSize = isSmallScreen ? 12.0 : 14.0;
    final dotSize = isSmallScreen ? 4.0 : 6.0;
    final dotSpacing = isSmallScreen ? 2.0 : 4.0;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedDate = date;
          });
        },
        borderRadius: BorderRadius.circular(8),
        splashColor: Theme.of(context).colorScheme.primary.withAlpha(76),
        highlightColor: Theme.of(context).colorScheme.primary.withAlpha(25),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : isToday
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Colors.transparent,
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : isToday
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : isToday
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : null,
                    fontSize: dateFontSize,
                  ),
                ),
                if (bookings.isNotEmpty) ...[
                  SizedBox(height: dotSpacing),
                  Container(
                    width: dotSize,
                    height: dotSize,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedDateBookings(String userId) {
    final firestoreService = ref.read(firestoreBookingsServiceProvider);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: firestoreService.getBookingsStream(userId, status: _statusFilter),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final allBookings = snapshot.data ?? [];
        final dayStart = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        final dayEnd = dayStart.add(const Duration(days: 1));

        final dayBookings = allBookings.where((booking) {
          final scheduledDate = booking['scheduledDate'] as DateTime;
          return scheduledDate.isAfter(dayStart.subtract(const Duration(seconds: 1))) &&
                 scheduledDate.isBefore(dayEnd);
        }).toList();

        dayBookings.sort((a, b) {
          final dateA = a['scheduledDate'] as DateTime;
          final dateB = b['scheduledDate'] as DateTime;
          return dateA.compareTo(dateB);
        });

        final dateStr = DateFormat('MMM d, yyyy').format(_selectedDate);

        // Responsive sizing for bookings section
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 800;
        final maxHeight = isSmallScreen ? 200.0 : 300.0;
        final padding = isSmallScreen ? 12.0 : 16.0;
        
        return Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding * 0.75),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(top: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bookings on $dateStr (${dayBookings.length})',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: isSmallScreen ? 13 : 15,
                    ),
              ),
              SizedBox(height: isSmallScreen ? 6 : 12),
              Flexible(
                child: dayBookings.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.event_busy,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No bookings for this date',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Scrollbar(
                        thumbVisibility: true,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: dayBookings.length,
                          itemBuilder: (context, index) {
                            return _buildBookingCard(dayBookings[index]);
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final scheduledDate = booking['scheduledDate'] as DateTime;
    final customerName = booking['customerName'] as String? ?? 'Unknown';
    final serviceName = booking['serviceName'] as String? ?? 'Service';
    final amount = booking['amount'] as double? ?? 0.0;
    final status = booking['status'] as String? ?? 'pending';
    final statusColor = _getStatusColor(status);
    
    // Responsive card width
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 800;
    final cardWidth = isSmallScreen ? 240.0 : 280.0;

    return Container(
      width: cardWidth,
      margin: EdgeInsets.only(right: isSmallScreen ? 8 : 12),
        child: Card(
        elevation: 2,
        child: InkWell(
          onTap: () {
            context.push('/bookings/${booking['id']}');
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        serviceName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(51),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        customerName,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('hh:mm a').format(scheduledDate),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Amount',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      '₹${amount.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<DateTime, List<Map<String, dynamic>>> _groupBookingsByDate(
    List<Map<String, dynamic>> bookings,
  ) {
    final bookingsByDate = <DateTime, List<Map<String, dynamic>>>{};
    final monthStart = DateTime(_displayMonth.year, _displayMonth.month, 1);
    final monthEnd = DateTime(_displayMonth.year, _displayMonth.month + 1, 0, 23, 59, 59);

    for (var booking in bookings) {
      final scheduledDate = booking['scheduledDate'] as DateTime;
      if (scheduledDate.isAfter(monthStart.subtract(const Duration(seconds: 1))) &&
          scheduledDate.isBefore(monthEnd.add(const Duration(seconds: 1)))) {
        final dateKey = DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day);
        bookingsByDate.putIfAbsent(dateKey, () => []).add(booking);
      }
    }

    return bookingsByDate;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.purple;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }
}

