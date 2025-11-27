import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kantin Poliwangi',
      theme: ThemeData(primarySwatch: Colors.orange),
      home: const MenuPage(),
    );
  }
}

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  final CollectionReference _menuRef =
      FirebaseFirestore.instance.collection('menus');

  final CollectionReference _orderRef =
      FirebaseFirestore.instance.collection('orders');

  String selectedCategory = "Semua";

  String formatRupiah(int price) {
    return NumberFormat.currency(
      locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0,
    ).format(price);
  }

  void _showOrderDialog(String menuName, int price) {
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Pesan $menuName"),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: "Nama Pemesan",
            hintText: "Contoh: Budi (TI-2A)",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                _orderRef.add({
                  'menu_item': menuName,
                  'price': price,
                  'customer_name': nameController.text,
                  'status': 'Menunggu',
                  'timestamp': FieldValue.serverTimestamp(),
                });

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Pesanan berhasil dikirim!")),
                );
              }
            },
            child: const Text("Pesan Sekarang"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Query menuQuery = _menuRef;
    if (selectedCategory != "Semua") {
      menuQuery =
          _menuRef.where('category', isEqualTo: selectedCategory);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("E-Canteen Poliwangi"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddMenuPage()),
              );
            },
          ),
        ],
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FilterButton(
                  label: "Semua",
                  active: selectedCategory == "Semua",
                  onTap: () => setState(() => selectedCategory = "Semua"),
                ),
                FilterButton(
                  label: "Makanan",
                  active: selectedCategory == "Makanan",
                  onTap: () => setState(() => selectedCategory = "Makanan"),
                ),
                FilterButton(
                  label: "Minuman",
                  active: selectedCategory == "Minuman",
                  onTap: () => setState(() => selectedCategory = "Minuman"),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder(
              stream: menuQuery.snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text("Terjadi kesalahan koneksi."));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("Menu belum tersedia."));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    Map<String, dynamic> data =
                        doc.data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.shade100,
                          child: Text(data['name'][0]),
                        ),
                        title: Text(
                          data['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(formatRupiah(data['price'] ?? 0)),
                            Text(
                              "Kategori: ${data['category']}",
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: data['isAvailable'] == true
                              ? () => _showOrderDialog(
                                  data['name'], data['price'])
                              : null,
                          child:
                              Text(data['isAvailable'] ? "Pesan" : "Habis"),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class FilterButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const FilterButton({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: active ? Colors.orange : Colors.grey[300],
        foregroundColor: active ? Colors.white : Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      onPressed: onTap,
      child: Text(label),
    );
  }
}

/// =====================================================
///  HALAMAN TAMBAH MENU
/// =====================================================

class AddMenuPage extends StatefulWidget {
  const AddMenuPage({super.key});

  @override
  State<AddMenuPage> createState() => _AddMenuPageState();
}

class _AddMenuPageState extends State<AddMenuPage> {
  final TextEditingController nameC = TextEditingController();
  final TextEditingController priceC = TextEditingController();

  String category = "Makanan";
  bool isAvailable = true;

  final CollectionReference menusRef =
      FirebaseFirestore.instance.collection('menus');

  void saveMenu() {
    if (nameC.text.isEmpty || priceC.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Semua field harus diisi!")),
      );
      return;
    }

    menusRef.add({
      'name': nameC.text,
      'price': int.parse(priceC.text),
      'category': category,
      'isAvailable': isAvailable,
      'created_at': FieldValue.serverTimestamp(),
    });

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Menu berhasil ditambahkan!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tambah Menu")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: nameC,
              decoration: const InputDecoration(
                labelText: "Nama Menu",
              ),
            ),
            TextField(
              controller: priceC,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Harga",
              ),
            ),

            const SizedBox(height: 20),

            DropdownButtonFormField(
              value: category,
              items: const [
                DropdownMenuItem(value: "Makanan", child: Text("Makanan")),
                DropdownMenuItem(value: "Minuman", child: Text("Minuman")),
              ],
              onChanged: (v) => setState(() => category = v!),
              decoration: const InputDecoration(labelText: "Kategori"),
            ),

            SwitchListTile(
              title: const Text("Tersedia"),
              value: isAvailable,
              onChanged: (v) => setState(() => isAvailable = v),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: saveMenu,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.orange,
              ),
              child: const Text(
                "Simpan Menu",
                style: TextStyle(fontSize: 18),
              ),
            )
          ],
        ),
      ),
    );
  }
}
