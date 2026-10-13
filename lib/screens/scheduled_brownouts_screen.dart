import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:suga/providers/power_interruption_provider.dart';
import 'package:suga/routes/app_routes.dart';

class ScheduledBrownoutsScreen extends StatefulWidget {
  const ScheduledBrownoutsScreen({super.key});

  @override
  State<ScheduledBrownoutsScreen> createState() => _ScheduledBrownoutsScreenState();
}

class _ScheduledBrownoutsScreenState extends State<ScheduledBrownoutsScreen> {
  @override
  void initState() {
    super.initState();
    // Load after the first frame, because notifyListeners() must not run during a build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<PowerInterruptionProvider>();
      if (!provider.hasLoaded) provider.loadInterruptions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PowerInterruptionProvider>();
    final items = provider.interruptions;

    final Widget body;
    if (items.isEmpty && (provider.isLoading || !provider.hasLoaded) && provider.error == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (items.isEmpty && provider.error != null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(provider.error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: provider.loadInterruptions, child: const Text('Retry')),
          ],
        ),
      );
    } else if (items.isEmpty) {
      body = const Center(child: Text('No scheduled brownouts'));
    } else {
      body = RefreshIndicator(
        onRefresh: provider.loadInterruptions,
        child: ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              title: Text(item.title),
              subtitle: Text(
                '${item.date} · ${item.startTime} – ${item.endTime}\n'
                '${item.affectedAreas.join(', ')}',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.brownoutDetails,
                arguments: item,
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Scheduled Brownouts')),
      body: body,
    );
  }
}
