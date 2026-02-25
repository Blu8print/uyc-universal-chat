// UYC - Unlock Your Cloud
// Endpoint Editor Screen

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/app_colors.dart';
import '../models/endpoint_model.dart';
import '../services/endpoint_service.dart';

class EndpointEditorScreen extends StatefulWidget {
  final Endpoint? endpoint; // null for new, populated for edit

  const EndpointEditorScreen({super.key, this.endpoint});

  @override
  State<EndpointEditorScreen> createState() => _EndpointEditorScreenState();
}

class _EndpointEditorScreenState extends State<EndpointEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _authValueController = TextEditingController();
  final _initialMessageController = TextEditingController();
  final _timeoutController = TextEditingController(text: '30');

  String _authType = 'none';
  bool _loadHistory = true;
  bool _isTesting = false;
  String? _testResult;
  bool? _testSuccess;

  @override
  void initState() {
    super.initState();
    if (widget.endpoint != null) {
      _loadEndpoint(widget.endpoint!);
    }
  }

  void _loadEndpoint(Endpoint endpoint) {
    _nameController.text = endpoint.name;
    _urlController.text = endpoint.url;
    _authType = endpoint.authType;
    _usernameController.text = endpoint.username ?? '';
    _authValueController.text = endpoint.authValue ?? '';
    _loadHistory = endpoint.loadHistory;
    _initialMessageController.text = endpoint.initialMessage ?? '';
    _timeoutController.text = endpoint.timeout.toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _usernameController.dispose();
    _authValueController.dispose();
    _initialMessageController.dispose();
    _timeoutController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isTesting = true;
      _testResult = null;
      _testSuccess = null;
    });

    try {
      final testEndpoint = Endpoint(
        id: 'test',
        name: _nameController.text,
        url: _urlController.text,
        authType: _authType,
        authValue: _authValueController.text.isEmpty ? null : _authValueController.text,
        username: _usernameController.text.isEmpty ? null : _usernameController.text,
        loadHistory: _loadHistory,
        timeout: int.tryParse(_timeoutController.text) ?? 30,
      );

      final headers = <String, String>{'Content-Type': 'application/json'};
      final authHeader = testEndpoint.getAuthHeader();
      if (authHeader != null) {
        if (_authType == 'header') {
          // Custom header format: "HeaderName: HeaderValue"
          final parts = authHeader.split(':');
          if (parts.length == 2) {
            headers[parts[0].trim()] = parts[1].trim();
          }
        } else {
          headers['Authorization'] = authHeader;
        }
      }

      final response = await http
          .post(
            Uri.parse(testEndpoint.url),
            headers: headers,
            body: jsonEncode({
              'action': 'sendMessage',
              'chatInput': 'Test connection',
              'sessionId': 'test_session',
            }),
          )
          .timeout(Duration(seconds: testEndpoint.timeout));

      if (response.statusCode == 200) {
        setState(() {
          _testSuccess = true;
          _testResult = 'Connection successful (${response.statusCode})';
        });
      } else {
        setState(() {
          _testSuccess = false;
          _testResult = 'Failed: ${response.statusCode} ${response.reasonPhrase}';
        });
      }
    } catch (e) {
      setState(() {
        _testSuccess = false;
        _testResult = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() => _isTesting = false);
    }
  }

  Future<void> _saveEndpoint() async {
    if (!_formKey.currentState!.validate()) return;

    final endpoint = Endpoint(
      id: widget.endpoint?.id ?? EndpointService.generateId(),
      name: _nameController.text,
      url: _urlController.text,
      authType: _authType,
      authValue: _authValueController.text.isEmpty ? null : _authValueController.text,
      username: _usernameController.text.isEmpty ? null : _usernameController.text,
      loadHistory: _loadHistory,
      initialMessage: _initialMessageController.text.isEmpty ? null : _initialMessageController.text,
      timeout: int.tryParse(_timeoutController.text) ?? 30,
      createdAt: widget.endpoint?.createdAt,
    );

    bool success;
    if (widget.endpoint == null) {
      success = await EndpointService.addEndpoint(endpoint);
    } else {
      success = await EndpointService.updateEndpoint(endpoint);
    }

    if (success && mounted) {
      Navigator.of(context).pop(true); // Return true to indicate save
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0x1A000000),
                border: Border(
                  bottom: BorderSide(color: Color(0x1AFFFFFF), width: 1),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: AppColors.textLight),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        widget.endpoint == null ? 'NEW ENDPOINT' : 'EDIT ENDPOINT',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                          color: AppColors.textLight,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // Balance back button
                ],
              ),
            ),

            // Form content
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Connection section
                    _buildSectionTitle('CONNECTION', Icons.link),
                    const SizedBox(height: 14),

                    _buildTextField(
                      controller: _nameController,
                      label: 'Endpoint Name',
                      hint: 'My Weather Bot',
                      validator: (v) => v?.isEmpty ?? true ? 'Name required' : null,
                    ),

                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _urlController,
                      label: 'Webhook URL',
                      hint: 'https://your-n8n.com/webhook/xxxxx/chat',
                      mono: true,
                      validator: (v) {
                        if (v?.isEmpty ?? true) return 'URL required';
                        if (!v!.startsWith('http')) return 'Must start with http:// or https://';
                        return null;
                      },
                    ),

                    const SizedBox(height: 8),
                    Text(
                      'The production Chat URL from your n8n Chat Trigger node',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textLight.withValues(alpha: 0.4),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Authentication section
                    _buildSectionTitle('AUTHENTICATION', Icons.lock),
                    const SizedBox(height: 14),

                    _buildDropdown(
                      label: 'Auth Type',
                      value: _authType,
                      items: const [
                        {'value': 'none', 'label': 'None (Public endpoint)'},
                        {'value': 'basic', 'label': 'Basic Auth'},
                        {'value': 'bearer', 'label': 'Bearer Token'},
                        {'value': 'header', 'label': 'Custom Header'},
                      ],
                      onChanged: (v) => setState(() => _authType = v!),
                    ),

                    const SizedBox(height: 16),

                    // Conditional auth fields
                    if (_authType == 'basic') ...[
                      _buildTextField(
                        controller: _usernameController,
                        label: 'Username',
                        hint: 'user',
                        validator: (v) => v?.isEmpty ?? true ? 'Username required' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _authValueController,
                        label: 'Password',
                        hint: '••••••••',
                        obscure: true,
                        validator: (v) => v?.isEmpty ?? true ? 'Password required' : null,
                      ),
                    ],

                    if (_authType == 'bearer')
                      _buildTextField(
                        controller: _authValueController,
                        label: 'Bearer Token',
                        hint: 'your-token-here',
                        mono: true,
                        validator: (v) => v?.isEmpty ?? true ? 'Token required' : null,
                      ),

                    if (_authType == 'header')
                      _buildTextField(
                        controller: _authValueController,
                        label: 'Custom Header',
                        hint: 'X-API-Key: your-key-here',
                        mono: true,
                        validator: (v) {
                          if (v?.isEmpty ?? true) return 'Header required';
                          if (!v!.contains(':')) return 'Format: HeaderName: HeaderValue';
                          return null;
                        },
                      ),

                    const SizedBox(height: 28),

                    // Settings section
                    _buildSectionTitle('SETTINGS', Icons.settings),
                    const SizedBox(height: 14),

                    _buildToggle(
                      label: 'Load Chat History',
                      description: 'Restore previous messages on reconnect',
                      value: _loadHistory,
                      onChanged: (v) => setState(() => _loadHistory = v),
                    ),

                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _timeoutController,
                      label: 'Connection Timeout (seconds)',
                      hint: '30',
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final num = int.tryParse(v ?? '');
                        if (num == null || num < 1) return 'Invalid timeout';
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _initialMessageController,
                      label: 'Initial Message (optional)',
                      hint: 'Hi! How can I help you today?',
                    ),

                    const SizedBox(height: 8),
                    Text(
                      'Shown as the first bot message when starting a new session',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textLight.withValues(alpha: 0.4),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Test connection button
                    _buildTestButton(),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Bottom action bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0x1A000000),
                border: Border(
                  top: BorderSide(color: Color(0x1AFFFFFF), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: AppColors.textLight.withValues(alpha: 0.12),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textLight.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _saveEndpoint,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppColors.accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 8,
                        shadowColor: AppColors.accent.withValues(alpha: 0.3),
                      ),
                      child: Text(
                        widget.endpoint == null ? 'Save Endpoint' : 'Update Endpoint',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textLight,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.accent),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 3,
            color: AppColors.textLight.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.textLight.withValues(alpha: 0.06),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool mono = false,
    bool obscure = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textLight.withValues(alpha: 0.6),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textLight,
            fontFamily: mono ? 'monospace' : null,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColors.textLight.withValues(alpha: 0.4),
            ),
            filled: true,
            fillColor: const Color(0x14FFFFFF),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.textLight.withValues(alpha: 0.12),
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.textLight.withValues(alpha: 0.12),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.accent,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFef4444),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<Map<String, String>> items,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textLight.withValues(alpha: 0.6),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          dropdownColor: AppColors.primary,
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textLight,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0x14FFFFFF),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.textLight.withValues(alpha: 0.12),
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.textLight.withValues(alpha: 0.12),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          items: items
              .map((item) => DropdownMenuItem<String>(
                    value: item['value'],
                    child: Text(item['label']!),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildToggle({
    required String label,
    required String description,
    required bool value,
    required void Function(bool) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.accent,
            activeTrackColor: AppColors.accent.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton() {
    Color? buttonColor;
    Color? borderColor;
    IconData? icon;

    if (_testSuccess == true) {
      buttonColor = const Color(0xFF4ade80).withValues(alpha: 0.08);
      borderColor = const Color(0xFF4ade80);
      icon = Icons.check_circle;
    } else if (_testSuccess == false) {
      buttonColor = const Color(0xFFef4444).withValues(alpha: 0.08);
      borderColor = const Color(0xFFef4444);
      icon = Icons.error;
    } else {
      buttonColor = const Color(0x0AFFFFFF);
      borderColor = AppColors.textLight.withValues(alpha: 0.15);
      icon = Icons.flash_on;
    }

    return Column(
      children: [
        OutlinedButton(
          onPressed: _isTesting ? null : _testConnection,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            backgroundColor: buttonColor,
            side: BorderSide(
              color: borderColor,
              width: 1.5,
              style: _testSuccess == null ? BorderStyle.solid : BorderStyle.solid,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isTesting)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                )
              else
                Icon(
                  icon,
                  size: 18,
                  color: _testSuccess == null
                      ? AppColors.textLight.withValues(alpha: 0.6)
                      : _testSuccess!
                          ? const Color(0xFF4ade80)
                          : const Color(0xFFef4444),
                ),
              const SizedBox(width: 8),
              Text(
                _isTesting
                    ? 'Testing...'
                    : _testSuccess == null
                        ? 'Test Connection'
                        : _testSuccess!
                            ? 'Success'
                            : 'Failed',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _testSuccess == null
                      ? AppColors.textLight.withValues(alpha: 0.6)
                      : _testSuccess!
                          ? const Color(0xFF4ade80)
                          : const Color(0xFFef4444),
                ),
              ),
            ],
          ),
        ),
        if (_testResult != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x0AFFFFFF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.textLight.withValues(alpha: 0.06),
              ),
            ),
            child: Text(
              _testResult!,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: AppColors.textLight.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
