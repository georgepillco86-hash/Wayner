import 'package:flutter/material.dart';

import '../models/usuario.dart';
import '../services/usuarios_service.dart';

class UsuariosAdminScreen extends StatefulWidget {
  const UsuariosAdminScreen({super.key});

  @override
  State<UsuariosAdminScreen> createState() => _UsuariosAdminScreenState();
}

class _UsuariosAdminScreenState extends State<UsuariosAdminScreen> {
  final UsuariosService _usuariosService = UsuariosService();

  bool _isLoading = true;
  String? _errorMessage;
  List<Usuario> _usuarios = [];

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
  }

  Future<void> _cargarUsuarios() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final usuarios = await _usuariosService.listarUsuarios();

      if (!mounted) return;

      setState(() {
        _usuarios = usuarios;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'No se pudieron cargar los usuarios';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _abrirFormularioUsuario({Usuario? usuario}) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (_) => _UsuarioFormDialog(usuario: usuario),
    );

    if (resultado == true) {
      await _cargarUsuarios();
    }
  }

  Future<void> _abrirCambioPassword(Usuario usuario) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (_) => _CambioPasswordDialog(usuario: usuario),
    );

    if (resultado == true) {
      await _cargarUsuarios();
    }
  }

  Future<void> _desactivarUsuario(Usuario usuario) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Desactivar usuario'),
        content: Text(
          '¿Seguro que deseas desactivar al usuario "${usuario.nombreUsuario}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await _usuariosService.desactivarUsuario(usuario.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario desactivado correctamente')),
      );

      await _cargarUsuarios();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo desactivar el usuario')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1F6F8B);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de usuarios'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _cargarUsuarios,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        onPressed: () => _abrirFormularioUsuario(),
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo usuario'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
      );
    }

    if (_usuarios.isEmpty) {
      return const Center(child: Text('No existen usuarios registrados'));
    }

    return RefreshIndicator(
      onRefresh: _cargarUsuarios,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _usuarios.length,
        itemBuilder: (context, index) {
          final usuario = _usuarios[index];

          // 🔥 NUEVO: Mostramos el celular en la tarjeta si existe
          final celularTexto =
              (usuario.celular != null && usuario.celular!.isNotEmpty)
              ? ' | Cel: ${usuario.celular}'
              : '';

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(
                child: Icon(usuario.activo ? Icons.person : Icons.person_off),
              ),
              title: Text(
                usuario.nombreUsuario,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${usuario.nombreCompleto ?? 'Sin nombre'}$celularTexto\nRol: ${usuario.rol} | Estado: ${usuario.activo ? 'Activo' : 'Inactivo'}',
              ),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'editar') {
                    _abrirFormularioUsuario(usuario: usuario);
                  } else if (value == 'password') {
                    _abrirCambioPassword(usuario);
                  } else if (value == 'desactivar') {
                    _desactivarUsuario(usuario);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'editar',
                    child: Text('Editar usuario'),
                  ),
                  const PopupMenuItem(
                    value: 'password',
                    child: Text('Cambiar contraseña'),
                  ),
                  const PopupMenuItem(
                    value: 'desactivar',
                    child: Text('Desactivar usuario'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _UsuarioFormDialog extends StatefulWidget {
  final Usuario? usuario;

  const _UsuarioFormDialog({this.usuario});

  @override
  State<_UsuarioFormDialog> createState() => _UsuarioFormDialogState();
}

class _UsuarioFormDialogState extends State<_UsuarioFormDialog> {
  final UsuariosService _usuariosService = UsuariosService();

  final _formKey = GlobalKey<FormState>();
  final _nombreUsuarioController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nombreCompletoController = TextEditingController();
  final _celularController =
      TextEditingController(); // 🔥 NUEVO: Controlador para celular

  bool _activo = true;
  bool _isSaving = false;
  String _rol = 'USER';

  bool get _isEditing => widget.usuario != null;

  @override
  void initState() {
    super.initState();

    final usuario = widget.usuario;

    if (usuario != null) {
      _nombreUsuarioController.text = usuario.nombreUsuario;
      _nombreCompletoController.text = usuario.nombreCompleto ?? '';
      _celularController.text =
          usuario.celular ?? ''; // 🔥 NUEVO: Cargar celular
      _rol = usuario.rol;
      _activo = usuario.activo;
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final celularIngresado = _celularController.text.trim();
      final celularFinal = celularIngresado.isEmpty ? null : celularIngresado;

      if (_isEditing) {
        await _usuariosService.actualizarUsuario(
          id: widget.usuario!.id,
          nombreUsuario: _nombreUsuarioController.text.trim(),
          nombreCompleto: _nombreCompletoController.text.trim(),
          celular: celularFinal, // 🔥 NUEVO: Pasamos el celular al servicio
          rol: _rol,
          activo: _activo,
        );
      } else {
        await _usuariosService.crearUsuario(
          nombreUsuario: _nombreUsuarioController.text.trim(),
          password: _passwordController.text.trim(),
          nombreCompleto: _nombreCompletoController.text.trim(),
          celular: celularFinal, // 🔥 NUEVO: Pasamos el celular al servicio
          rol: _rol,
          activo: _activo,
        );
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar el usuario')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nombreUsuarioController.dispose();
    _passwordController.dispose();
    _nombreCompletoController.dispose();
    _celularController.dispose(); // 🔥 NUEVO: Liberar memoria
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Editar usuario' : 'Nuevo usuario'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nombreUsuarioController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de usuario',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa el nombre de usuario';
                    }
                    if (value.trim().length < 3) {
                      return 'Mínimo 3 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                if (!_isEditing) ...[
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa la contraseña';
                      }
                      if (value.trim().length < 3) {
                        return 'Mínimo 3 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _nombreCompletoController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                // 🔥 NUEVO: Campo para el celular
                TextFormField(
                  controller: _celularController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Celular',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone_android),
                  ),
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      final cel = value.replaceAll(' ', '').replaceAll('-', '');
                      if (cel.length != 10 || int.tryParse(cel) == null) {
                        return 'Debe tener exactamente 10 números';
                      }
                    }
                    return null; // Es opcional, así que si está vacío no marca error
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _rol,
                  isExpanded:
                      true, // 🔥 CORRECCIÓN: Esto soluciona el "Right overflowed"
                  decoration: const InputDecoration(
                    labelText: 'Rol',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'ADMIN',
                      child: Text('ADMIN - Administrador'),
                    ),
                    DropdownMenuItem(
                      value: 'USER',
                      child: Text('USER - Usuario normal'),
                    ),
                    DropdownMenuItem(
                      value: 'BODEGUERO',
                      child: Text('BODEGUERO - Recepción de pedidos'),
                    ),
                    DropdownMenuItem(
                      value: 'ESCANER',
                      child: Text('ESCANER - Solo escáner'),
                    ),
                    DropdownMenuItem(
                      value: 'TRABAJADOR',
                      child: Text('TRABAJADOR'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _rol = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Usuario activo'),
                  value: _activo,
                  onChanged: (value) {
                    setState(() {
                      _activo = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _guardar,
          child: Text(_isSaving ? 'Guardando...' : 'Guardar'),
        ),
      ],
    );
  }
}

class _CambioPasswordDialog extends StatefulWidget {
  final Usuario usuario;

  const _CambioPasswordDialog({required this.usuario});

  @override
  State<_CambioPasswordDialog> createState() => _CambioPasswordDialogState();
}

class _CambioPasswordDialogState extends State<_CambioPasswordDialog> {
  final UsuariosService _usuariosService = UsuariosService();

  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();

  bool _isSaving = false;

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await _usuariosService.cambiarPassword(
        id: widget.usuario.id,
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cambiar la contraseña')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Cambiar contraseña de ${widget.usuario.nombreUsuario}'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Nueva contraseña',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingresa la nueva contraseña';
              }
              if (value.trim().length < 3) {
                return 'Mínimo 3 caracteres';
              }
              return null;
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _guardar,
          child: Text(_isSaving ? 'Guardando...' : 'Cambiar'),
        ),
      ],
    );
  }
}
