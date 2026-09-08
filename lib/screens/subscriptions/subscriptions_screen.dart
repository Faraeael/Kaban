import 'package:flutter/material.dart';
import '../recurring/recurring_screen.dart';

/// Legacy screen entrypoint that delegates to the unified [RecurringScreen]
/// with the Subscriptions tab (index 1) preselected.
class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RecurringScreen(initialTab: 1);
  }
}
