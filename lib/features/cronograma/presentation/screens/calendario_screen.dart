import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../data/models/visita_model.dart';
import '../../data/services/cronograma_service.dart';
import 'cronograma_form_screen.dart';
import 'administracion_proveedores_screen.dart';

class CalendarioScreen extends StatefulWidget {
  const CalendarioScreen({super.key});

  @override
  State<CalendarioScreen> createState() => _CalendarioScreenState();
}

class _CalendarioScreenState extends State<CalendarioScreen> {
  final _cronogramaService = CronogramaService();

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Visita>> _visitasMes = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _cargarMes(_focusedDay.year, _focusedDay.month);
  }

  Future<void> _cargarMes(int year, int month) async {
    setState(() => _isLoading = true);
    try {
      final visitas = await _cronogramaService.obtenerVisitasDelMes(
        year,
        month,
      );

      final Map<DateTime, List<Visita>> visitasAgrupadas = {};
      for (var v in visitas) {
        final fechaDia = DateTime(
          v.fechaProgramada.year,
          v.fechaProgramada.month,
          v.fechaProgramada.day,
        );
        if (visitasAgrupadas[fechaDia] == null) visitasAgrupadas[fechaDia] = [];
        visitasAgrupadas[fechaDia]!.add(v);
      }

      setState(() => _visitasMes = visitasAgrupadas);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Visita> _getVisitasDelDia(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _visitasMes[normalizedDay] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final visitasSeleccionadas = _selectedDay != null
        ? _getVisitasDelDia(_selectedDay!)
        : [];

    return Scaffold(
      backgroundColor:
          Colors.grey.shade50, // Fondo general ligeramente gris para contraste
      appBar: AppBar(
        title: const Text(
          'Calendario de Pedidos',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: Icon(
              Icons.format_list_bulleted,
              color: Colors.blueGrey.shade700,
            ),
            tooltip: 'Administración de proveedores',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdministracionProveedoresScreen(
                    onChanged: () =>
                        _cargarMes(_focusedDay.year, _focusedDay.month),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.add_circle, color: Theme.of(context).primaryColor),
            tooltip: 'Programar Nuevo',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CronogramaFormScreen(
                  onSaved: () =>
                      _cargarMes(_focusedDay.year, _focusedDay.month),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 1. EL CALENDARIO (CONTENEDOR BLANCO)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(bottom: 12),
            child: TableCalendar<Visita>(
              firstDay: DateTime.now().subtract(const Duration(days: 365)),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              calendarFormat: CalendarFormat.month,
              eventLoader: _getVisitasDelDia,
              startingDayOfWeek: StartingDayOfWeek.monday,

              // Estilo de la cabecera (Mes y Año)
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),

              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
                _cargarMes(focusedDay.year, focusedDay.month);
              },

              onDaySelected: (selectedDay, focusedDay) {
                if (!isSameDay(_selectedDay, selectedDay)) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                }
              },

              // Estilos de los días
              calendarStyle: CalendarStyle(
                markerDecoration: const BoxDecoration(
                  color: Colors.orangeAccent,
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 3,
                todayDecoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(
                  color: Colors.blue.shade800,
                  fontWeight: FontWeight.bold,
                ),
                selectedDecoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                outsideDaysVisible: false,
              ),
            ),
          ),

          // 2. BANNER SEPARADOR ELEGANTE
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(
                top: BorderSide(color: Colors.grey.shade300),
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: Colors.blueGrey.shade600,
                ),
                const SizedBox(width: 8),
                Text(
                  'Pedidos del ${DateFormat('dd MMM yyyy').format(_selectedDay ?? _focusedDay)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.blueGrey.shade800,
                  ),
                ),
              ],
            ),
          ),

          // 3. LISTA DE PEDIDOS DEL DÍA SELECCIONADO
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : visitasSeleccionadas.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Día libre de pedidos',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 24),
                    itemCount: visitasSeleccionadas.length,
                    itemBuilder: (context, index) {
                      final visita = visitasSeleccionadas[index];
                      final esPendiente =
                          visita.estado.toLowerCase() == 'pendiente';

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            // Ícono con fondo
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.local_shipping,
                                color: Colors.blue.shade700,
                                size: 24,
                              ),
                            ),
                            title: Text(
                              visita.proveedor,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        DateFormat(
                                          'HH:mm',
                                        ).format(visita.fechaProgramada),
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.person_outline,
                                        size: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          visita.usuariosVinculados.join(", "),
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Etiqueta de Estado (Chip Moderno)
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: esPendiente
                                    ? Colors.orange.shade50
                                    : Colors.green.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: esPendiente
                                      ? Colors.orange.shade200
                                      : Colors.green.shade200,
                                ),
                              ),
                              child: Text(
                                visita.estado,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: esPendiente
                                      ? Colors.orange.shade800
                                      : Colors.green.shade800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
