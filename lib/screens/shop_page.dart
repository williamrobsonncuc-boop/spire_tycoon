import 'package:flutter/material.dart';

import '../game/game_model.dart';
import '../theme/app_colors.dart';

/// A price list that looks like a shop. Nothing here charges a card.
class ShopPage extends StatelessWidget {
  const ShopPage({super.key, required this.game});

  final GameModel game;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: navy,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: cream,
        title: const Text('Shop'),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: game,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  key: const Key('practice-shop'),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: crimson,
                    borderRadius: BorderRadius.circular(cornerRadius),
                  ),
                  child: const Text(
                    'PRACTICE SHOP. Prices are for show. Test purchase grants TEST diamonds and moves no real money.',
                    style: TextStyle(
                      color: cream,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'TEST diamonds on hand: ${game.testDiamonds}',
                  style: const TextStyle(color: cyan, fontSize: 16),
                ),
                const SizedBox(height: 12),
                for (final item in practiceCatalog)
                  _ShopRow(game: game, item: item),
              ],
            );
          },
        ),
      ),
    );
  }
}

class PracticeItem {
  const PracticeItem({
    required this.id,
    required this.name,
    required this.price,
    required this.detail,
    required this.testDiamonds,
  });

  final String id;
  final String name;
  final String price;
  final String detail;
  final int testDiamonds;
}

const List<PracticeItem> practiceCatalog = [
  PracticeItem(
    id: 'intern',
    name: 'Intern Pack',
    price: '£1.99',
    detail: 'A paper hat and five practice diamonds.',
    testDiamonds: 5,
  ),
  PracticeItem(
    id: 'manager',
    name: "Manager's Choice",
    price: '£14.99',
    detail: 'Forty practice diamonds. The manager is still fictional.',
    testDiamonds: 40,
  ),
  PracticeItem(
    id: 'vault',
    name: 'Boardroom Vault',
    price: '£89.99',
    detail: 'A large pile of practice diamonds. The vault is cardboard.',
    testDiamonds: 250,
  ),
  PracticeItem(
    id: 'coffee',
    name: 'Coffee Pass',
    price: '£4.99/mo',
    detail: 'Shown as a monthly pass. Nothing is billed. 15 practice diamonds.',
    testDiamonds: 15,
  ),
  PracticeItem(
    id: 'platinum',
    name: 'Executive Platinum',
    price: '£9.99/mo',
    detail: 'Shown as a monthly pass. Nothing is billed. 30 practice diamonds.',
    testDiamonds: 30,
  ),
];

class _ShopRow extends StatelessWidget {
  const _ShopRow({required this.game, required this.item});

  final GameModel game;
  final PracticeItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: slate,
        borderRadius: BorderRadius.circular(cornerRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${item.name}  ${item.price}',
            style: const TextStyle(
              color: cream,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.detail,
            style: const TextStyle(color: cream, fontSize: 14, height: 1.3),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: Key('test-buy-${item.id}'),
            style: FilledButton.styleFrom(
              backgroundColor: emerald,
              foregroundColor: cream,
            ),
            onPressed: () => game.grantTestDiamonds(item.testDiamonds),
            child: Text('Test purchase · +${item.testDiamonds} TEST diamonds'),
          ),
        ],
      ),
    );
  }
}
