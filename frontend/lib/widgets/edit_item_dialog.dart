import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api.dart';
import '../models/item.dart';

typedef ItemUpdateHandler =
    Future<Item> Function({
      required Item item,
      required String name,
      required int quantity,
      required String measure,
      required String? price,
      required bool bought,
    });

class EditItemDialog extends StatefulWidget {
  final Item item;
  final ItemUpdateHandler onSave;

  const EditItemDialog({super.key, required this.item, required this.onSave});

  @override
  State<EditItemDialog> createState() => _EditItemDialogState();
}

class _EditItemDialogState extends State<EditItemDialog> {
  static const _measures = ['un', 'g', 'kg', 'ml', 'l'];
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;
  late String _measure;
  late bool _bought;
  bool _saving = false;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _quantityController = TextEditingController(
      text: widget.item.quantity.toString(),
    );
    _priceController = TextEditingController(
      text: widget.item.price?.replaceFirst('.', ',') ?? '',
    );
    _measure = widget.item.measure;
    _bought = widget.item.bought;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  String? _normalizedPrice() {
    final text = _priceController.text.trim();
    return text.isEmpty ? null : text.replaceAll(',', '.');
  }

  Future<void> _submit() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _serverError = null;
    });
    try {
      final updated = await widget.onSave(
        item: widget.item,
        name: _nameController.text.trim(),
        quantity: int.parse(_quantityController.text.trim()),
        measure: _measure,
        price: _normalizedPrice(),
        bought: _bought,
      );
      if (mounted) Navigator.of(context).pop(updated);
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _serverError = exception is ApiException
            ? exception.message
            : 'Não foi possível salvar o item. Tente novamente.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Editar item'),
    content: SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: true,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Nome'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Informe o nome do item.'
                  : null,
            ),
            TextFormField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Quantidade'),
              validator: (value) {
                final quantity = int.tryParse(value?.trim() ?? '');
                return quantity == null || quantity < 1
                    ? 'Informe uma quantidade a partir de 1.'
                    : null;
              },
            ),
            DropdownButtonFormField<String>(
              key: const ValueKey('item-measure-dropdown'),
              initialValue: _measures.contains(_measure) ? _measure : null,
              decoration: const InputDecoration(labelText: 'Medida'),
              items: _measures
                  .map(
                    (measure) =>
                        DropdownMenuItem(value: measure, child: Text(measure)),
                  )
                  .toList(growable: false),
              onChanged: _saving
                  ? null
                  : (measure) {
                      if (measure != null) setState(() => _measure = measure);
                    },
              validator: (measure) =>
                  measure == null || !_measures.contains(measure)
                  ? 'Selecione uma medida.'
                  : null,
            ),
            TextFormField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Preço',
                hintText: 'Opcional',
                prefixText: 'R\$ ',
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return null;
                return RegExp(r'^[0-9]{1,8}([.,][0-9]{1,2})?$').hasMatch(text)
                    ? null
                    : 'Informe até 8 dígitos inteiros e 2 decimais.';
              },
              onFieldSubmitted: (_) => _submit(),
            ),
            CheckboxListTile(
              key: const ValueKey('item-bought-checkbox'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Comprado'),
              value: _bought,
              onChanged: _saving
                  ? null
                  : (bought) => setState(() => _bought = bought ?? false),
            ),
            if (_serverError != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _serverError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton.icon(
        onPressed: _saving ? null : _submit,
        icon: _saving
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_outlined),
        label: Text(_saving ? 'Salvando…' : 'Salvar'),
      ),
    ],
  );
}
