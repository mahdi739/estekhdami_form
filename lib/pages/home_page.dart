import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:estekhdami_form/widgets/items_form_field.dart';
import 'package:estekhdami_form/widgets/segment_form_field.dart';

final supabase = Supabase.instance.client;

class Info {
  String formFiller;
  int callNumber;
  String jobTitle;
  String qualifications;
  TaskType taskType;
  int staffNumber;
  List<String> perks;
  String docs;
  Info({
    this.formFiller = '',
    this.callNumber = 0,
    this.jobTitle = '',
    this.qualifications = '',
    this.taskType = TaskType.main,
    this.staffNumber = 0,
    this.perks = const [],
    this.docs = '',
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _formKey = GlobalKey<FormState>();
  final _info = Info();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 500,
          ),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(15)),
          child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'نام تکمیل کننده فرم الزامیست';
                        }
                      },
                      decoration: const InputDecoration(labelText: 'نام تکمیل کننده فرم'),
                      onSaved: (v) {
                        _info.formFiller = v ?? '';
                      }),
                  TextFormField(
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'شماره تماس الزامیست';
                        }
                      },
                      textAlign: TextAlign.left,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'شماره تماس'),
                      onSaved: (v) {
                        _info.callNumber = int.tryParse(v ?? '') ?? 0;
                      }),
                  TextFormField(
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'عنوان شغل الزامیست';
                        }
                      },
                      decoration: const InputDecoration(labelText: 'عنوان شغل'),
                      onSaved: (v) {
                        _info.jobTitle = v ?? '';
                      }),
                  TextFormField(
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'شرایط احراز تحصیلی یا تجربی الزامیست';
                        }
                      },
                      decoration: const InputDecoration(labelText: 'شرایط احراز تحصیلی یا تجربی'),
                      onSaved: (v) {
                        _info.qualifications = v ?? '';
                      }),
                  SegmentFormField(validator: (TaskType? value) {
                    if (value != null) {
                      return null;
                    } else {
                      return 'یک گزینه را انتخاب کنید';
                    }
                  }, onSaved: (TaskType? v) {
                    _info.taskType = v ?? TaskType.main;
                  }),
                  TextFormField(
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'تعداد نیروها الزامیست';
                        }
                        var parsed = int.tryParse(value) ?? 0;
                        if (parsed <= 0) {
                          return 'تعداد نیروها باید بزرگتر از صفر باشد';
                        }
                      },
                      textAlign: TextAlign.left,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'تعداد نیروها به نفر'),
                      onSaved: (v) {
                        _info.staffNumber = int.tryParse(v ?? '') ?? 0;
                      }),
                  ItemsFormField(
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'حداقل یک آیتم اضافه کنید';
                        } else {
                          return null;
                        }
                      },
                      decoration: const InputDecoration(labelText: 'اقلام حقوق و مزایا با ذکر نام'),
                      onSaved: (List<String>? v) {
                        _info.perks = v ?? [];
                      }),
                  TextFormField(
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'مستندات قانونی پرداخت حقوق و مزایا الزامیست';
                        }
                      },
                      decoration: const InputDecoration(labelText: 'مستندات قانونی پرداخت حقوق و مزایا'),
                      onSaved: (v) {
                        _info.docs = v ?? '';
                      }),
                  ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          _formKey.currentState!.save();
                          try {
                            await supabase.from('info').insert(
                              {
                                'form_filler': _info.formFiller,
                                'call_number': _info.callNumber,
                                'job_title': _info.jobTitle,
                                'qualifications': _info.qualifications,
                                'task_type': _info.taskType.code,
                                'staff_number': _info.staffNumber,
                                'perks': _info.perks,
                                'docs': _info.docs,
                              },
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('با موفقیت ثبت شد')));
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                          }
                        }
                      },
                      child: const Text('ثبت اطلاعات'))
                ],
              )),
        ),
      ),
    );
  }
}
