import 'package:flutter/material.dart';

class AddressInput extends StatelessWidget {
  final TextEditingController pickupController;
  final TextEditingController dropoffController;
  final void Function(String text) onPickupSearch;
  final void Function(String text) onDropoffSearch;
  final String pickupLabel;
  final String dropoffLabel;

  const AddressInput({
    Key? key,
    required this.pickupController,
    required this.dropoffController,
    required this.onPickupSearch,
    required this.onDropoffSearch,
    required this.pickupLabel,
    required this.dropoffLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          TextField(
            controller: pickupController,
            decoration: InputDecoration(
              labelText: "🚖 乗車住所を入力",
              suffixIcon: IconButton(
                icon: Icon(Icons.search),
                onPressed: () => onPickupSearch(pickupController.text),
              ),
            ),
          ),
          SizedBox(height: 8),
          TextField(
            controller: dropoffController,
            decoration: InputDecoration(
              labelText: "🏁 目的地住所を入力",
              suffixIcon: IconButton(
                icon: Icon(Icons.search),
                onPressed: () => onDropoffSearch(dropoffController.text),
              ),
            ),
          ),
          // SizedBox(height: 8),
          // Text("🚗 乗車地: $pickupLabel"),
          // Text("📍 目的地: $dropoffLabel"),
        ],
      ),
    );
  }
}
