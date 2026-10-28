import 'package:flutter/material.dart';
import '../../../../ui/core/theme/app_colors.dart';
import '../../data/profile_repository.dart';
import '../profile_edit_view_model.dart';
import 'profile_form_page.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key, required this.repository});
  final ProfileRepository repository;
  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  late final model = ProfileEditViewModel(widget.repository)..load();
  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      if (model.loading || (!model.loaded && model.error != null)) {
        return Scaffold(
          appBar: AppBar(title: const Text('신체정보 수정')),
          body: Center(
            child: model.loading
                ? const CircularProgressIndicator()
                : Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          model.error!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: model.load,
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      }
      return PopScope(
        canPop: !model.saving,
        child: ProfileFormPage(
          model: model,
          editing: true,
          onCancel: () => Navigator.pop(context),
          onSaved: () => Navigator.pop(context, model.saved),
        ),
      );
    },
  );
}
