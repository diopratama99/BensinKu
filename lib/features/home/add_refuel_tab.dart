import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models.dart';
import '../../data/repository.dart';

class AddRefuelTab extends StatefulWidget {
  const AddRefuelTab({super.key});

  @override
  State<AddRefuelTab> createState() => _AddRefuelTabState();
}

class _AddRefuelTabState extends State<AddRefuelTab> {
  final _repo = SupabaseRepository.ofDefaultClient();

  final _odometerController = TextEditingController();
  final _totalController = TextEditingController();

  DateTime _refuelDate = DateTime.now();
  String? _vehicleId;
  String? _fuelProductId;
  bool _isFullTank = true;

  bool _saving = false;
  String? _error;

  final _rupiah = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  final _dateFmt = DateFormat('dd MMM yyyy', 'id_ID');

  @override
  void dispose() {
    _odometerController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  num? _parseNumber(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isEmpty) return null;
    return num.tryParse(cleaned);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: cs.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: cs.onPrimaryContainer.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.local_gas_station_rounded,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Input Pengisian',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: cs.onPrimaryContainer,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Nominal (Rp) saja. Liter dihitung otomatis dari harga.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: cs.onPrimaryContainer.withValues(
                                  alpha: 0.85,
                                ),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildDateSection(context),
          const SizedBox(height: 12),
          FutureBuilder<List<Vehicle>>(
            future: _repo.listVehicles(),
            builder: (context, snapshot) {
              final vehicles = snapshot.data;
              if (snapshot.hasError) {
                return _ErrorCard(
                  title: 'Gagal load kendaraan',
                  message: snapshot.error.toString(),
                );
              }
              if (vehicles == null) {
                return const _LoadingCard(title: 'Memuat kendaraan...');
              }
              if (vehicles.isEmpty) {
                return _ErrorCard(
                  title: 'Belum ada kendaraan',
                  message: 'Tambahkan kendaraan terlebih dahulu di halaman Profil.',
                );
              }
              return _buildVehicleDropdown(vehicles);
            },
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<FuelProduct>>(
            future: _repo.listFuelProducts(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _ErrorCard(
                  title: 'Gagal load fuel products',
                  message: snapshot.error.toString(),
                );
              }

              final products = snapshot.data;
              if (products == null) {
                return const _LoadingCard(title: 'Memuat daftar BBM...');
              }

              if (products.isEmpty) {
                return const _ErrorCard(
                  title: 'Daftar BBM kosong',
                  message:
                      'Seed dulu tabel fuel_products di Supabase (Pertamina + Shell).',
                );
              }

              return _buildFuelDropdown(products);
            },
          ),
          const SizedBox(height: 12),
          _buildInputs(),
          const SizedBox(height: 12),
          if (_vehicleId != null && _fuelProductId != null)
            FutureBuilder<FuelPrice?>(
              future: _repo.getFuelPrice(
                fuelProductId: _fuelProductId!,
                onDate: _refuelDate,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _ErrorCard(
                    title: 'Gagal ambil harga',
                    message: snapshot.error.toString(),
                  );
                }

                final price = snapshot.data;
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _LoadingCard(title: 'Mengambil harga...');
                }

                if (price == null) {
                  return const _ErrorCard(
                    title: 'Harga tidak ditemukan',
                    message:
                        'Tambahkan fuel_prices untuk BBM ini (effective_from <= tanggal input).',
                  );
                }

                return _buildComputedCard(price.pricePerLiter);
              },
            ),
          const SizedBox(height: 12),
          _buildSaveButton(context),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorCard(title: 'Tidak bisa menyimpan', message: _error!),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildDateSection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.event_rounded),
                const SizedBox(width: 8),
                Text('Tanggal', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.calendar_month_rounded,
                  color: cs.onSecondaryContainer,
                ),
              ),
              title: Text(
                _dateFmt.format(_refuelDate),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                'Tap untuk ubah tanggal pengisian',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _refuelDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked == null) return;
                if (!mounted) return;
                setState(() => _refuelDate = picked);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleDropdown(List<Vehicle> vehicles) {
    if (_vehicleId == null && vehicles.isNotEmpty) {
      _vehicleId = vehicles.first.id;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: DropdownButtonFormField<String>(
          key: ValueKey(_vehicleId),
          initialValue: _vehicleId,
          decoration: const InputDecoration(labelText: 'Kendaraan'),
          items: vehicles
              .map(
                (v) => DropdownMenuItem(
                  value: v.id,
                  child: Text('${v.type.label} — ${v.name}'),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _vehicleId = value),
        ),
      ),
    );
  }

  Widget _buildFuelDropdown(List<FuelProduct> products) {
    if (_fuelProductId == null && products.isNotEmpty) {
      _fuelProductId = products.first.id;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: DropdownButtonFormField<String>(
          key: ValueKey(_fuelProductId),
          initialValue: _fuelProductId,
          decoration: const InputDecoration(labelText: 'Jenis BBM'),
          items: products
              .map(
                (p) => DropdownMenuItem(
                  value: p.id,
                  child: Text(p.label),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _fuelProductId = value),
        ),
      ),
    );
  }

  Widget _buildInputs() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _odometerController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Spidometer (km) (opsional)',
                hintText: 'Contoh: 12345',
                prefixIcon: Icon(Icons.speed_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _totalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Nominal (Rp)',
                hintText: 'Contoh: 10000',
                prefixIcon: Icon(Icons.payments_rounded),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isFullTank,
              onChanged: (value) => setState(() => _isFullTank = value),
              title: const Text('Full tank'),
              subtitle: const Text('Aktifkan supaya perhitungan efisiensi lebih akurat.'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComputedCard(num pricePerLiter) {
    final cs = Theme.of(context).colorScheme;
    final total = _parseNumber(_totalController.text);
    final liters = (total == null || pricePerLiter <= 0)
        ? null
        : (total / pricePerLiter);

    return Card(
      color: cs.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: cs.onSecondaryContainer),
                const SizedBox(width: 8),
                Text(
                  'Otomatis',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: cs.onSecondaryContainer,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Harga / liter: ${_rupiah.format(pricePerLiter)}',
              style: TextStyle(color: cs.onSecondaryContainer),
            ),
            const SizedBox(height: 6),
            Text(
              liters == null
                  ? 'Liter: —'
                  : 'Liter: ${liters.toStringAsFixed(3)} L',
              style: TextStyle(
                color: cs.onSecondaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    return FilledButton.icon(
      onPressed: _saving ? null : () => _save(context),
      icon: const Icon(Icons.save),
      label: _saving
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Simpan Pengisian'),
    );
  }

  Future<void> _save(BuildContext context) async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final messenger = ScaffoldMessenger.of(context);
      final vehicleId = _vehicleId;
      final fuelProductId = _fuelProductId;
      if (vehicleId == null) throw StateError('Pilih kendaraan');
      if (fuelProductId == null) throw StateError('Pilih jenis BBM');

      final odometer = _parseNumber(_odometerController.text);

      final total = _parseNumber(_totalController.text);
      if (total == null) throw StateError('Nominal wajib diisi');

      final price = await _repo.getFuelPrice(
        fuelProductId: fuelProductId,
        onDate: _refuelDate,
      );
      if (price == null) {
        throw StateError('Harga BBM belum ada untuk tanggal ini');
      }

      final pricePerLiter = price.pricePerLiter;
      if (pricePerLiter <= 0) throw StateError('Harga per liter tidak valid');

      final liters = total / pricePerLiter;
      await _repo.createRefuel(
        vehicleId: vehicleId,
        fuelProductId: fuelProductId,
        refuelDate: DateTime(
          _refuelDate.year,
          _refuelDate.month,
          _refuelDate.day,
        ),
        odometerKm: odometer,
        totalRp: total,
        pricePerLiterSnapshot: pricePerLiter,
        liters: liters,
        isFullTank: _isFullTank,
      );

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Tersimpan')),
      );

      setState(() {
        _odometerController.clear();
        _totalController.clear();
        _isFullTank = true;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}



class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ],
        ),
      ),
    );
  }
}
