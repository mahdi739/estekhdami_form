import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:collection/collection.dart';
import 'package:estekhdami_form/widgets/items_form_field.dart';
import 'package:estekhdami_form/widgets/segment_form_field.dart';

import '../storage_service.dart';
part 'home_page.freezed.dart';
part 'home_page.g.dart';

final supabase = Supabase.instance.client;

@JsonEnum(valueField: 'code')
enum TaskType {
  main('اصلی', 0),
  support('پشتیبانی', 1);

  final int code;
  final String label;
  const TaskType(this.label, this.code);
  String toJson() => code.toString();
  static TaskType fromJson(int code) => values.firstWhere((element) => element.code == code);
}

@freezed
class Info with _$Info {
  // int? id;
  // String depName;
  // String orgName;
  // String formFiller;
  // int callNumber;
  // String jobTitle;
  // String qualifications;
  // TaskType taskType;
  // int staffNumber;
  // int averageSalary;
  // List<String> perks;
  // bool sent;
  // String docs;
  const factory Info({
    @Default(null)  int? id,
    @Default(false)  bool sent,
    @Default('')  String depName,
    @Default('')  String orgName,
    @Default('')  String formFiller,
    @Default(0)  int callNumber,
    @Default('')  String jobTitle,
    @Default('')  String qualifications,
    @Default(TaskType.main)  TaskType taskType,
    @Default(0)  int staffNumber,
    @Default(0)  int averageSalary,
    @Default([])  List<String> perks,
    @Default('')  String docs,
  }) = _Info;
  factory Info.fromJson(Map<String, Object?> json) => _$InfoFromJson(json);

  // factory Info.fromMap(Map<String, dynamic> map) {
  //   return Info(
  //     id: map['id'],
  //     depName: map['depName'] ?? '',
  //     orgName: map['orgName'] ?? '',
  //     formFiller: map['formFiller'] ?? '',
  //     callNumber: map['callNumber'] ?? 0,
  //     jobTitle: map['jobTitle'] ?? '',
  //     qualifications: map['qualifications'] ?? '',
  //     taskType: TaskType.fromJson(map['taskType']),
  //     staffNumber: map['staffNumber'] ?? 0,
  //     averageSalary: map['averageSalary'] ?? 0,
  //     perks: (map['perks'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
  //     sent: map['sent'] ?? false,
  //     docs: map['docs'] ?? '',
  //   );
  // }

  // Map<String, dynamic> toJson() {
  //   return {
  //     'id': id,
  //     'depName': depName,
  //     'orgName': orgName,
  //     'formFiller': formFiller,
  //     'callNumber': callNumber,
  //     'jobTitle': jobTitle,
  //     'qualifications': qualifications,
  //     'taskType': taskType.code,
  //     'staffNumber': staffNumber,
  //     'averageSalary': averageSalary,
  //     'perks': perks,
  //     'sent': sent,
  //     'docs': docs,
  //   };
  // }

  // factory Info.fromJson(String source) => Info.fromMap(json.decode(source));
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _depName = '';
  String _orgName = '';
  String _formFiller = '';
  int _callNumber = 0;
  String _jobTitle = '';
  String _qualifications = '';
  TaskType _taskType = TaskType.main;
  int _staffNumber = 0;
  int _averageSalary = 0;
  List<String> _perks = [];
  String _docs = '';

  final _formKey = GlobalKey<FormState>();
  // final _info = Info();
  final _isSending = BehaviorSubject.seeded(false);
  final _infos = BehaviorSubject.seeded(<Info>[]);
  final _sents = BehaviorSubject.seeded(<bool>[]);
  final _infoBuilder = <String, dynamic>{};
  @override
  void initState() {
    _infos.listen((value) {
      _sents.sink.add(value.map((e) => e.sent).toList());
    });
    _infos.add([]);
    _infos.add((StorageService.instance.getStringList('savedInfo') ?? []).map((e) => Info.fromJson(jsonDecode(e))).toList());
    super.initState();
  }

  Future<bool> _upload(final Info _info, int index) async {
    try {
      _isSending.add(true);
      List<Map<String, dynamic>> id = await supabase.from('info').insert(
        {
          'form_filler': _info.formFiller,
          'average_salary': _info.averageSalary,
          'dep_name': _info.depName,
          'org_name': _info.orgName,
          'call_number': _info.callNumber,
          'job_title': _info.jobTitle,
          'qualifications': _info.qualifications,
          'task_type': _info.taskType.code,
          'staff_number': _info.staffNumber,
          'perks': _info.perks,
          'docs': _info.docs,
        },
      ).select('id');
      // _info.id = (id.first['id'] as int);
      // _info.sent = true;
      _infos.add(_infos.value.mapIndexed((i, value) => i != index ? value : _info.copyWith(sent: true, id: (id.first['id'] as int))).toList());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('با موفقیت ثبت شد'),
          duration: Duration(seconds: 10),
        ));
      }
      return true;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: SelectableText(e.toString())));
      return false;
    } finally {
      _isSending.add(false);

      StorageService.instance.setStringList(
          'savedInfo',
          _infos.value.map((e) {
            String saving = e.toJson().toString();
            print(saving);
            return saving;
          }).toList());
    }
  }

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
                          return 'عنوان موسسه الزامیست';
                        }
                      },
                      decoration: const InputDecoration(labelText: 'عنوان موسسه'),
                      onSaved: (v) {
                        _orgName = v ?? '';
                      }),
                  TextFormField(
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'نام واحد سازمانی تکمیل کننده اطلاعات الزامیست';
                        }
                      },
                      decoration: const InputDecoration(labelText: 'نام واحد سازمانی تکمیل کننده اطلاعات'),
                      onSaved: (v) {
                        _depName = v ?? '';
                      }),
                  TextFormField(
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'نام تکمیل کننده فرم الزامیست';
                        }
                      },
                      decoration: const InputDecoration(labelText: 'نام تکمیل کننده فرم'),
                      onSaved: (v) {
                        _formFiller = v ?? '';
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
                        _callNumber = int.tryParse(v ?? '') ?? 0;
                      }),
                  TextFormField(
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'عنوان شغل الزامیست';
                        }
                      },
                      decoration: const InputDecoration(labelText: 'عنوان شغل'),
                      onSaved: (v) {
                        _jobTitle = v ?? '';
                      }),
                  TextFormField(
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'شرایط احراز تحصیلی یا تجربی الزامیست';
                        }
                      },
                      decoration: const InputDecoration(labelText: 'شرایط احراز تحصیلی یا تجربی'),
                      onSaved: (v) {
                        _qualifications = v ?? '';
                      }),
                  SegmentFormField(validator: (TaskType? value) {
                    if (value != null) {
                      return null;
                    } else {
                      return 'یک گزینه را انتخاب کنید';
                    }
                  }, onSaved: (TaskType? v) {
                    _taskType = v ?? TaskType.main;
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
                        _staffNumber = int.tryParse(v ?? '') ?? 0;
                      }),
                  TextFormField(
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'میانگین حقوق و مزایای پرداختی به تومان (بدون حق عائله مندی) الزامیست';
                        }
                        var parsed = int.tryParse(value) ?? 0;
                        if (parsed <= 0) {
                          return 'میانگین حقوق و مزایای پرداختی به تومان (بدون حق عائله مندی) باید بزرگتر از صفر باشد';
                        }
                      },
                      textAlign: TextAlign.left,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'میانگین حقوق و مزایای پرداختی به تومان (بدون حق عائله مندی)'),
                      onSaved: (v) {
                        _averageSalary = int.tryParse(v ?? '') ?? 0;
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
                        _perks = v ?? [];
                      }),
                  TextFormField(
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'مستندات قانونی پرداخت حقوق و مزایا الزامیست';
                        }
                      },
                      decoration: const InputDecoration(labelText: 'مستندات قانونی پرداخت حقوق و مزایا'),
                      onSaved: (v) {
                        _docs = v ?? '';
                      }),
                  StreamBuilder<bool>(
                      initialData: false,
                      stream: _isSending.stream,
                      builder: (context, snapshot) {
                        return ElevatedButton(
                            onPressed: snapshot.data == false
                                ? () async {
                                    if (_formKey.currentState!.validate()) {
                                      _formKey.currentState!.save();
                                      final _info = Info(
                                          id: null,
                                          orgName: _orgName,
                                          depName: _depName,
                                          formFiller: _formFiller,
                                          jobTitle: _jobTitle,
                                          callNumber: _callNumber,
                                          qualifications: _qualifications,
                                          staffNumber: _staffNumber,
                                          perks: _perks,
                                          averageSalary: _averageSalary,
                                          taskType: _taskType,
                                          docs: _docs,
                                          sent: false);
                                      _infos.sink.add([_info, ..._infos.value]);

                                      // StorageService.instance.setStringList(
                                      //     'savedInfo',
                                      //     _infos.value.map((e) {
                                      //       String saving = jsonEncode(e);
                                      //       print(saving);
                                      //       return saving;
                                      //     }).toList());
                                      var res = await _upload(_info, 0);
                                    }
                                  }
                                : null,
                            child: const Text('ثبت اطلاعات'));
                      }),
                  StreamBuilder<List<Info>>(
                      stream: _infos.stream,
                      initialData: const [],
                      builder: (context, snapshot) {
                        return Table(
                          children: snapshot.data!
                              .mapIndexed((index, e) => TableRow(children: [
                                    TableCell(
                                        child: StreamBuilder<List<bool>>(
                                      stream: _sents.stream,
                                      initialData: null,
                                      builder: (context, snapshot) {
                                        if (snapshot.data == null) {
                                          return const Text('');
                                        } else if (snapshot.data![index] == true) {
                                          return const Text('ثبت شد✅');
                                        } else {
                                          return Column(
                                            children: [
                                              const Text('ثبت نشد⚠'),
                                              StreamBuilder<bool>(
                                                  stream: _isSending.stream,
                                                  builder: (context, snapshot) {
                                                    return ElevatedButton(
                                                        onPressed: snapshot.data == false ? () => _upload(e, index) : null,
                                                        child: const Text('تلاش مجدد'));
                                                  })
                                            ],
                                          );
                                        }
                                      },
                                    )),
                                    TableCell(child: Text(e.orgName)),
                                    TableCell(child: Text(e.qualifications)),
                                    TableCell(child: Text(e.taskType.label)),
                                    TableCell(child: Text(e.staffNumber.toString())),
                                    TableCell(child: Text(e.averageSalary.toString())),
                                    TableCell(child: Text(e.perks.mapIndexed((index, q) => '${index}_$q').join('\n'))),
                                    TableCell(child: Text(e.docs)),
                                  ]))
                              .toList(),
                        );
                      })
                ],
              )),
        ),
      ),
    );
  }
}
