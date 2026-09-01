// [CẬP NHẬT FILE: lib/screens/manager/reports.dart]

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:myshop/models/order.dart';
import 'package:myshop/models/staff_profile.dart';
import 'package:myshop/models/best_seller_item.dart';
import 'package:myshop/models/schedule_exception.dart'; // <-- Import mới
import 'package:myshop/services/pocketbase_service.dart';
import 'package:myshop/utils/currency_formatter.dart';
import 'package:pocketbase/pocketbase.dart';

class DailyRevenue {
  final DateTime date;
  final double total;
  final double cost;
  double get profit => total - cost;
  DailyRevenue({required this.date, required this.total, required this.cost});
}

// ReportData: Orders, StaffProfiles, BestSellers, RawItems, SpoilageCost, Exceptions
typedef ReportData = (
  List<OrderModel>, // 0
  List<StaffProfile>, // 1
  List<BestSellerItem>, // 2
  List<RecordModel>, // 3
  double, // 4: spoilageCost
  List<ScheduleExceptionModel>, // 5: exceptions (MỚI)
);

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final pbService = PocketBaseService.instance;

  DateTime _selectedMonth = DateTime.now();
  late Future<ReportData> _reportDataFuture;

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  void _loadReportData() {
    if (mounted) {
      setState(() {
        _reportDataFuture =
            Future.wait([
              pbService.reports.getCompletedOrdersForMonth(_selectedMonth),
              pbService.users.getStaffProfiles(),
              pbService.reports.getBestSellingItems(_selectedMonth),
              pbService.reports.getRawSoldItems(_selectedMonth),
              pbService.reports.getMonthlySpoilageCost(_selectedMonth),
              pbService.schedules.getAllExceptionsInMonth(
                _selectedMonth,
              ), // <-- MỚI
            ]).then((results) {
              return (
                results[0] as List<OrderModel>,
                results[1] as List<StaffProfile>,
                results[2] as List<BestSellerItem>,
                results[3] as List<RecordModel>,
                results[4] as double,
                results[5] as List<ScheduleExceptionModel>, // <-- MỚI
              );
            });
      });
    }
  }

  void _changeMonth(int a) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + a,
        1,
      );
      if (_selectedMonth.isAfter(DateTime.now())) {
        _selectedMonth = DateTime.now();
      }
    });
    _loadReportData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo cáo'),
        backgroundColor: Colors.amber.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildMonthPicker(),
          Expanded(
            child: FutureBuilder<ReportData>(
              future: _reportDataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Lỗi: ${snapshot.error}'));
                }

                // Lấy dữ liệu từ snapshot
                final orders = snapshot.data?.$1 ?? [];
                final profiles = snapshot.data?.$2 ?? [];
                final bestSellers = snapshot.data?.$3 ?? [];
                final rawItems = snapshot.data?.$4 ?? [];
                final spoilageCost = snapshot.data?.$5 ?? 0.0;
                final exceptions =
                    snapshot.data?.$6 ?? []; // <-- Lấy exceptions

                // 1. Xử lý doanh thu & giá vốn
                final (dailyData, totalRevenue, totalCOGS, busiestDay) =
                    _processReportData(orders, rawItems);

                // 2. Tính lương thực nhận (MỚI)
                final (totalPayroll, salaryMap) = _calculateRealPayroll(
                  profiles,
                  exceptions,
                );

                // 3. Tính lợi nhuận
                final double grossProfit = totalRevenue - totalCOGS;
                final double netProfit =
                    grossProfit - totalPayroll - spoilageCost;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSummaryCard(
                      revenue: totalRevenue,
                      grossProfit: grossProfit,
                      netProfit: netProfit,
                      spoilageCost: spoilageCost,
                      totalOrders: orders.length,
                      busiestDay: busiestDay,
                    ),
                    const SizedBox(height: 16),
                    // Truyền thêm salaryMap vào card
                    _buildPayrollCard(
                      totalPayroll,
                      profiles,
                      context,
                      salaryMap,
                    ),
                    const SizedBox(height: 24),
                    _buildBestSellersCard(bestSellers),
                    const SizedBox(height: 24),
                    Text(
                      'Biểu đồ Doanh thu & Lợi nhuận gộp',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    _buildBarChart(dailyData),
                    const SizedBox(height: 30),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- HÀM TÍNH LƯƠNG THỰC TẾ (MỚI) ---
  (double, Map<String, double>) _calculateRealPayroll(
    List<StaffProfile> profiles,
    List<ScheduleExceptionModel> exceptions,
  ) {
    double total = 0;
    Map<String, double> map = {};

    for (var p in profiles) {
      // Chỉ tính cho nhân viên đang hoạt động
      if (p.status != 'active') continue;

      double realSalary = p.salary;

      // Tìm các lỗi vi phạm của nhân viên này
      final userExceptions = exceptions.where((e) => e.staffProfileId == p.id);

      for (var ex in userExceptions) {
        if (ex.type == ScheduleExceptionType.late ||
            ex.type == ScheduleExceptionType.unexcused) {
          realSalary -= ex.penalty; // Trừ tiền phạt
        }
        // Nếu muốn cộng tiền làm thêm (extraShift), bạn có thể thêm logic ở đây
        if (ex.type == ScheduleExceptionType.extraShift) {
          realSalary += ex.bonus; // <-- Cộng lương làm thêm
        }
      }

      // Đảm bảo lương không âm
      if (realSalary < 0) realSalary = 0;

      total += realSalary;
      map[p.id] = realSalary;
    }
    return (total, map);
  }

  // --- XỬ LÝ REPORT DATA ---
  (List<DailyRevenue>, double, double, String) _processReportData(
    List<OrderModel> orders,
    List<RecordModel> rawItems,
  ) {
    double totalRevenue = 0;
    double totalCost = 0;
    Map<String, DailyRevenue> dailyMap = {};

    for (var item in rawItems) {
      final createdStr = item.getStringValue('created');
      if (createdStr.isEmpty) continue;

      final date = DateTime.parse(createdStr).toLocal();
      final dayKey = DateFormat('yyyy-MM-dd').format(date);

      final quantity = item.getIntValue('quantity');
      final price = item.getDoubleValue('price');

      double unitCost = 0.0;
      if (item.expand.containsKey('menu_item') &&
          item.expand['menu_item']!.isNotEmpty) {
        final menuItemRecord = item.expand['menu_item']!.first;
        unitCost = menuItemRecord.getDoubleValue('cost');
      }

      final itemRevenue = price * quantity;
      final itemCost = unitCost * quantity;

      totalRevenue += itemRevenue;
      totalCost += itemCost;

      if (dailyMap.containsKey(dayKey)) {
        var current = dailyMap[dayKey]!;
        dailyMap[dayKey] = DailyRevenue(
          date: current.date,
          total: current.total + itemRevenue,
          cost: current.cost + itemCost,
        );
      } else {
        dailyMap[dayKey] = DailyRevenue(
          date: DateTime.parse(dayKey),
          total: itemRevenue,
          cost: itemCost,
        );
      }
    }

    String busiestDay = "N/A";
    if (orders.isNotEmpty) {
      Map<int, int> weekdayCounts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
      for (var o in orders) {
        weekdayCounts[o.created.weekday] =
            (weekdayCounts[o.created.weekday] ?? 0) + 1;
      }
      final sortedDays = weekdayCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (sortedDays.first.value > 0) {
        busiestDay = _getWeekdayName(sortedDays.first.key);
      }
    }

    final List<DailyRevenue> dailyData = dailyMap.values.toList();
    dailyData.sort((a, b) => a.date.compareTo(b.date));

    return (dailyData, totalRevenue, totalCost, busiestDay);
  }

  // --- CÁC WIDGET HIỂN THỊ ---

  Widget _buildSummaryCard({
    required double revenue,
    required double grossProfit,
    required double netProfit,
    required double spoilageCost,
    required int totalOrders,
    required String busiestDay,
  }) {
    return Card(
      elevation: 4,
      color: Colors.amber.shade900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _buildSummaryItem(
                      'Doanh thu',
                      formatCurrency(revenue),
                      small: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _buildSummaryItem(
                      'Lãi gộp',
                      formatCurrency(grossProfit),
                      small: true,
                      isHighlight: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Chi phí hao hụt (hủy hàng):',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    spoilageCost > 0
                        ? "-${formatCurrency(spoilageCost)}"
                        : "Không có",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: spoilageCost > 0
                          ? Colors.redAccent.shade100
                          : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'LỢI NHUẬN RÒNG:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      formatCurrency(netProfit),
                      style: TextStyle(
                        color: netProfit >= 0
                            ? Colors.lightGreenAccent
                            : Colors.redAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _buildSummaryItem(
                      'Tổng Đơn',
                      '$totalOrders',
                      small: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _buildSummaryItem(
                      'Đông nhất',
                      busiestDay,
                      small: true,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthPicker() {
    final now = DateTime.now();
    final isCurrentMonth =
        _selectedMonth.year == now.year && _selectedMonth.month == now.month;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      color: Colors.amber.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeMonth(-1),
          ),
          Flexible(
            child: Text(
              "Tháng ${DateFormat('MM/yyyy').format(_selectedMonth)}",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: isCurrentMonth ? null : () => _changeMonth(1),
          ),
        ],
      ),
    );
  }

  Widget _buildPayrollCard(
    double totalPayroll,
    List<StaffProfile> profiles,
    BuildContext context,
    Map<String, double> salaryMap,
  ) {
    final activeStaff = profiles.where((p) => p.status == 'active').length;

    // Thay InkWell bằng Card thường (Không bấm được)
    return Card(
      elevation: 4,
      color: Colors.indigo.shade700,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildSummaryItem(
                  'Tổng Lương',
                  formatCurrency(totalPayroll),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: _buildSummaryItem('Nhân viên', '$activeStaff'),
              ),
            ),
            // Đã xóa Icon(Icons.chevron_right)
          ],
        ),
      ),
    );
  }

  Widget _buildBestSellersCard(List<BestSellerItem> items) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top 5 Món Bán Chạy',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Text('Chưa có dữ liệu.')
            else
              ...items
                  .take(5)
                  .map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Colors.amber.shade100,
                        child: Text('${items.indexOf(item) + 1}'),
                      ),
                      title: Text(item.menuItem.name),
                      trailing: Text(
                        '${item.totalQuantity} (lượt)',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(List<DailyRevenue> data) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('Không có dữ liệu')),
      );
    }

    double maxY =
        data.map((e) => e.total).fold(0.0, (p, c) => c > p ? c : p) * 1.2;
    if (maxY < 100000) maxY = 100000;

    return SizedBox(
      height: 300,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Colors.amber.shade800,
              getTooltipItem: (group, _, rod, __) {
                final d = data[group.x];
                return BarTooltipItem(
                  '${DateFormat('dd/MM').format(d.date)}\n',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  children: [
                    TextSpan(
                      text: 'DT: ${formatCurrency(d.total)}\n',
                      style: const TextStyle(color: Colors.white),
                    ),
                    TextSpan(
                      text: 'LN Gộp: ${formatCurrency(d.profit)}',
                      style: const TextStyle(color: Colors.lightGreenAccent),
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 45,
                getTitlesWidget: (v, m) {
                  if (v == 0 || v == maxY) {
                    return Text(
                      _formatShortCurrency(v),
                      style: const TextStyle(fontSize: 10),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, m) {
                  final d = data[v.toInt()].date;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('dd').format(d),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          barGroups: data
              .asMap()
              .entries
              .map(
                (e) => BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: e.value.total,
                      color: Colors.amber,
                      width: 12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    BarChartRodData(
                      toY: e.value.profit,
                      color: Colors.green,
                      width: 12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value, {
    bool small = false,
    bool isHighlight = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white70, fontSize: small ? 14 : 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          value,
          style: TextStyle(
            color: isHighlight ? Colors.lightGreenAccent : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: small ? 20 : 24,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  String _getWeekdayName(int weekday) {
    const days = {
      1: 'Thứ 2',
      2: 'Thứ 3',
      3: 'Thứ 4',
      4: 'Thứ 5',
      5: 'Thứ 6',
      6: 'Thứ 7',
      7: 'CN',
    };
    return days[weekday] ?? '';
  }

  String _formatShortCurrency(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}tr';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
    return value.toStringAsFixed(0);
  }
}
