import 'package:flutter/material.dart';

class SelectorUnidadMedida extends StatefulWidget {
  final String unidadInicial;
  final List<String>
  unidadesDisponibles; // 🔥 NUEVO: Recibe las unidades desde la BD
  final ValueChanged<String> onChanged;

  const SelectorUnidadMedida({
    super.key,
    required this.unidadInicial,
    required this.unidadesDisponibles, // 🔥 Requerido en el constructor
    required this.onChanged,
  });

  @override
  State<SelectorUnidadMedida> createState() => _SelectorUnidadMedidaState();
}

class _SelectorUnidadMedidaState extends State<SelectorUnidadMedida> {
  late String unidadActual;

  @override
  void initState() {
    super.initState();
    // Validamos que la unidad inicial exista en la lista dinámica que viene de la BD
    if (widget.unidadesDisponibles.isEmpty) {
      unidadActual = widget.unidadInicial; // Fallback por seguridad
    } else {
      unidadActual = widget.unidadesDisponibles.contains(widget.unidadInicial)
          ? widget.unidadInicial
          : widget.unidadesDisponibles.first;
    }
  }

  void _cambiarUnidad(int delta) {
    if (widget.unidadesDisponibles.isEmpty) return;

    int idx = widget.unidadesDisponibles.indexOf(unidadActual);
    idx = (idx + delta) % widget.unidadesDisponibles.length;
    if (idx < 0) idx = widget.unidadesDisponibles.length - 1; // Ciclo infinito

    setState(() {
      unidadActual = widget.unidadesDisponibles[idx];
    });
    widget.onChanged(unidadActual);
  }

  @override
  Widget build(BuildContext context) {
    // Si por alguna razón no hay unidades, evitamos que la UI colapse
    if (widget.unidadesDisponibles.isEmpty) {
      return const SizedBox(
        height: 32,
        width: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => _cambiarUnidad(-1),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.chevron_left, size: 18, color: Colors.grey),
            ),
          ),

          PopupMenuButton<String>(
            initialValue: unidadActual,
            tooltip: "Seleccionar unidad",
            onSelected: (val) {
              setState(() => unidadActual = val);
              widget.onChanged(unidadActual);
            },
            itemBuilder: (context) => widget.unidadesDisponibles
                .map(
                  (m) => PopupMenuItem(
                    value: m,
                    child: Text(m, style: const TextStyle(fontSize: 14)),
                  ),
                )
                .toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              child: Text(
                unidadActual,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.blue.shade800,
                ),
              ),
            ),
          ),

          InkWell(
            onTap: () => _cambiarUnidad(1),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.chevron_right, size: 18, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
