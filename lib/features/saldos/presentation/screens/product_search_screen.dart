import 'package:ferrotienda_flutter_proyecto/features/pedidos/screens/pedido_busqueda_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

// 🔥 IMPORT DE LA VENTANA FLOTANTE DE FAVORITOS 🔥
import 'package:ferrotienda_flutter_proyecto/features/favoritos/providers/favorites_flotante_dialog.dart';
// 🔥 IMPORT DE LA VENTANA PUBLICIDAD
import '../../../publicidad/screens/administrar_publicidad_screen.dart';

import '../widgets/product_card.dart';
import 'barcode_scanner_screen.dart';
import 'product_search_controller.dart';
import '../../../auth/screens/login_screen.dart';
import '../../../pedidos/screens/mis_pedidos_screen.dart';
import '../../../pedidos/screens/admin_pedidos_screen.dart';
import '../../../pedidos/screens/bodega_pedidos_screen.dart';
import '../../../../core/storage/session_storage.dart';
import '../../../usuarios/screens/usuarios_admin_screen.dart';
import '../../../pedidos/screens/unidades_medida_admin_screen.dart';
import '../../../logs/screens/audit_logs_screen.dart';
import '../../../promociones/screens/promociones_screen.dart';
import '../../../mermas/presentation/screens/merma_screen.dart';
import '../../../conversiones/screens/conversiones_screen.dart';
import '../../../cronograma/presentation/screens/calendario_screen.dart';
import '../../../cronograma/presentation/screens/notificaciones_screen.dart';
import '../../data/services/saldos_api_service.dart';

// Módulos KPI
import '../../../kpi/screens/admin_kpi_screen.dart';
import '../../../kpi/screens/mis_tareas_screen.dart';

// 🔥 NUEVO IMPORT DEL MÓDULO DE FECHAS ESPECIALES (PROPHET) 🔥
import '../../../pedidos/screens/eventos_calendario_screen.dart';

class ProductSearchScreen extends StatefulWidget {
  const ProductSearchScreen({super.key});

  @override
  State<ProductSearchScreen> createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends State<ProductSearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool _busquedaProfunda = false;
  bool esAdmin = false;
  bool esBodeguero = false;

  String nombreUsuario = "";
  String rolUsuario = "";

  int _notificacionesSinLeer = 2;

  @override
  void initState() {
    super.initState();
    _cargarRol();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductSearchController>().loadInitialData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarRol() async {
    final user = await SessionStorage.getUser();

    if (!mounted) return;

    final rol = user?.rol.trim().toUpperCase() ?? "";

    setState(() {
      esAdmin = rol == 'ADMIN';
      esBodeguero = rol == 'BODEGUERO';
      nombreUsuario = user?.nombreUsuario ?? "";
      rolUsuario = rol;
    });
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();

    if (!mounted) return;

    if (status.isDenied) {
      _showCameraPermissionDialog();
    } else if (status.isPermanentlyDenied) {
      _showCameraSettingsDialog();
    }
  }

  Future<bool> _ensureCameraPermission() async {
    final status = await Permission.camera.status;

    if (status.isGranted) return true;

    final requestedStatus = await Permission.camera.request();

    if (requestedStatus.isGranted) return true;

    if (!mounted) return false;

    if (requestedStatus.isPermanentlyDenied) {
      _showCameraSettingsDialog();
    } else {
      _showCameraPermissionDialog();
    }

    return false;
  }

  void _showCameraPermissionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Permiso de cámara'),
        content: const Text(
          'La app necesita acceso a la cámara para escanear códigos de barras o QR.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _requestCameraPermission();
            },
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  void _showCameraSettingsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Permiso bloqueado'),
        content: const Text(
          'El permiso de cámara está bloqueado. Debes activarlo desde la configuración de la app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Abrir ajustes'),
          ),
        ],
      ),
    );
  }

  Future<void> _openScanner() async {
    final hasPermission = await _ensureCameraPermission();

    if (!hasPermission || !mounted) return;

    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );

    if (code != null && code.isNotEmpty && mounted) {
      _searchController.text = code;
      await context.read<ProductSearchController>().search(code);
    }
  }

  Future<void> logout() async {
    await SessionStorage.clear();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void abrirPantalla(Widget pantalla) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
  }

  Widget buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    'assets/images/wyner_logo.png',
                    height: 58,
                    width: 58,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) {
                      return const Icon(Icons.store, size: 42);
                    },
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "WyNer",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  if (nombreUsuario.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      nombreUsuario,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                  if (rolUsuario.isNotEmpty)
                    Text(
                      "Rol: $rolUsuario",
                      style: const TextStyle(fontSize: 13),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  buildMenuItem(
                    icon: Icons.search,
                    title: "Inventario",
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(),

                  if (rolUsuario != 'ESCANER')
                    buildMenuItem(
                      icon: Icons.checklist_rtl,
                      title: "Mis Tareas Diarias",
                      onTap: () {
                        abrirPantalla(const MisTareasScreen());
                      },
                    ),

                  if (!esBodeguero) ...[
                    buildMenuItem(
                      icon: Icons.shopping_cart,
                      title: "Realizar pedido",
                      onTap: () {
                        abrirPantalla(const PedidoBusquedaScreen());
                      },
                    ),
                    buildMenuItem(
                      icon: Icons.list_alt,
                      title: "Mis pedidos",
                      onTap: () {
                        abrirPantalla(const MisPedidosScreen());
                      },
                    ),
                  ],
                  buildMenuItem(
                    icon: Icons.report_problem_outlined,
                    title: "Ingresar Merma",
                    onTap: () {
                      abrirPantalla(
                        MermaScreen(
                          usuarioActual: nombreUsuario,
                          rolUsuario: rolUsuario,
                          esModoReporte: false,
                        ),
                      );
                    },
                  ),

                  if (rolUsuario != 'ESCANER')
                    buildMenuItem(
                      icon: Icons.transform,
                      title: "Conversiones",
                      onTap: () {
                        abrirPantalla(const ConversionesScreen());
                      },
                    ),

                  if (esAdmin) ...[
                    const Divider(),
                    buildMenuItem(
                      icon: Icons.leaderboard_outlined,
                      title: "Rendimiento (KPI)",
                      onTap: () {
                        abrirPantalla(const AdminKpiScreen());
                      },
                    ),
                    buildMenuItem(
                      icon: Icons.assignment_turned_in_outlined,
                      title: "Reporte de mermas",
                      onTap: () {
                        abrirPantalla(
                          MermaScreen(
                            usuarioActual: nombreUsuario,
                            rolUsuario: rolUsuario,
                            esModoReporte: true,
                          ),
                        );
                      },
                    ),
                    buildMenuItem(
                      icon: Icons.admin_panel_settings,
                      title: "Administrar pedidos",
                      onTap: () {
                        abrirPantalla(const AdminPedidosScreen());
                      },
                    ),
                  ],
                  if (esAdmin || esBodeguero) ...[
                    buildMenuItem(
                      icon: Icons.inventory,
                      title: "Recepción de pedidos",
                      onTap: () {
                        abrirPantalla(BodegaPedidosScreen());
                      },
                    ),
                  ],
                  if (esAdmin) ...[
                    const Divider(),
                    buildMenuItem(
                      icon: Icons.manage_accounts,
                      title: "Gestionar usuarios",
                      onTap: () {
                        abrirPantalla(const UsuariosAdminScreen());
                      },
                    ),
                    buildMenuItem(
                      icon: Icons.calendar_month,
                      title: "Calendario de Pedidos",
                      onTap: () {
                        abrirPantalla(const CalendarioScreen());
                      },
                    ),
                    buildMenuItem(
                      icon: Icons.auto_awesome_mosaic,
                      title: "Fechas Especiales (IA)",
                      onTap: () {
                        abrirPantalla(const EventosCalendarioScreen());
                      },
                    ),
                    buildMenuItem(
                      icon: Icons.straighten,
                      title: "Unidades de medida",
                      onTap: () {
                        abrirPantalla(const UnidadesMedidaAdminScreen());
                      },
                    ),
                    buildMenuItem(
                      icon: Icons.local_offer,
                      title: "Promociones",
                      onTap: () {
                        abrirPantalla(const PromocionesScreen());
                      },
                    ),
                    // 🔥 NUEVO MÓDULO DE PUBLICIDAD (Solo visible para ADMIN)
                    buildMenuItem(
                      icon: Icons.ondemand_video,
                      title: "Administrar publicidad",
                      onTap: () {
                        abrirPantalla(const AdministrarPublicidadScreen());
                      },
                    ),
                    buildMenuItem(
                      icon: Icons.receipt_long,
                      title: "Logs del sistema",
                      onTap: () {
                        abrirPantalla(const AuditLogsScreen());
                      },
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                "Cerrar sesión",
                style: TextStyle(color: Colors.red),
              ),
              onTap: logout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassFilter(ProductSearchController controller) {
    return DropdownButtonFormField<String>(
      value: controller.selectedClass,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Filtrar por clase',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.category_outlined),
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('Todas las clases'),
        ),
        ...controller.classes.map(
          (clase) => DropdownMenuItem<String>(
            value: clase,
            child: Text(clase, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: controller.filterByClass,
    );
  }

  Widget _buildProviderFilter(ProductSearchController controller) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            final query = textEditingValue.text.trim().toLowerCase();

            if (query.isEmpty) {
              return controller.providers.take(20);
            }

            return controller.providers.where(
              (proveedor) => proveedor.toLowerCase().contains(query),
            );
          },
          displayStringForOption: (option) => option,
          onSelected: (String proveedor) {
            controller.filterByProvider(proveedor);
          },
          fieldViewBuilder:
              (context, textEditingController, focusNode, onFieldSubmitted) {
                if (controller.selectedProvider == null) {
                  textEditingController.clear();
                } else if (textEditingController.text !=
                    controller.selectedProvider) {
                  textEditingController.text = controller.selectedProvider!;
                }

                return TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: 'Filtrar por proveedor',
                    hintText: 'Escriba el nombre del proveedor',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.local_shipping_outlined),
                    suffixIcon: controller.selectedProvider == null
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              textEditingController.clear();
                              controller.filterByProvider(null);
                            },
                          ),
                  ),
                );
              },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  width: constraints.maxWidth,
                  constraints: const BoxConstraints(maxHeight: 250),
                  color: Theme.of(context).colorScheme.surface,
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      return InkWell(
                        onTap: () => onSelected(option),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 14.0,
                          ),
                          child: Text(
                            option,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProductSearchController>();

    return Scaffold(
      drawer: buildDrawer(),
      appBar: AppBar(
        title: const Text('Inventario'),
        actions: [
          // 🔥 NUEVO: BOTÓN ESTRELLA ABRE LA VENTANA FLOTANTE 🔥
          IconButton(
            icon: const Icon(Icons.star_rounded, color: Colors.amber, size: 28),
            tooltip: 'Mis Favoritos',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const FavoritesFlotanteDialog(),
              );
            },
          ),
          Center(
            child: Badge(
              isLabelVisible: _notificacionesSinLeer > 0,
              backgroundColor: Colors.red,
              label: Text(
                _notificacionesSinLeer.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
              child: IconButton(
                icon: const Icon(Icons.notifications_active),
                tooltip: 'Notificaciones',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificacionesScreen(),
                    ),
                  ).then((_) {
                    if (mounted) {
                      setState(() {
                        _notificacionesSinLeer = 0;
                      });
                    }
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Buscar producto',
                      hintText: 'Código, nombre, marca o clase',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    onSubmitted: controller.search,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () => controller.search(_searchController.text),
                  icon: const Icon(Icons.search),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _openScanner,
                  icon: const Icon(Icons.qr_code_scanner),
                ),
              ],
            ),
          ),
          SwitchListTile(
            activeColor: Colors.blue,
            title: const Text(
              'Búsqueda Profunda (Kardex General)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: const Text(
              'Útil si el producto es nuevo y no aparece en la lista.',
            ),
            value: controller.isDeepSearch,
            onChanged: (bool value) {
              controller.isDeepSearch = value;
              final textoActual = _searchController.text.trim();
              if (textoActual.isNotEmpty) {
                controller.search(textoActual);
              } else {
                controller.toggleDeepSearch(value);
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _buildClassFilter(controller),
          ),
          if (esAdmin) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _buildProviderFilter(controller),
            ),
          ],
          if (controller.errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              controller.errorMessage!,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onErrorContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: controller.refresh,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Reintentar'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (controller.isLoading) const LinearProgressIndicator(),
          Expanded(
            child: controller.products.isEmpty && !controller.isLoading
                ? const Center(child: Text('No hay productos para mostrar'))
                : ListView.builder(
                    itemCount: controller.products.length,
                    itemBuilder: (context, index) {
                      final product = controller.products[index];
                      return ProductCard(product: product, esAdmin: esAdmin);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
