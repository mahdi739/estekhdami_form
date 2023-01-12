import 'dart:async';
import 'dart:convert';

import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:persian_number_utility/persian_number_utility.dart';
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
  // String toJson() => code.toString();
  // static TaskType fromJson(int code) => values.firstWhere((element) => element.code == code);
}

@JsonEnum(valueField: 'code')
enum SyncState {
  writing(0),
  inserting(1),
  inserted(2),
  insertFailed(3),
  updating(4),
  updated(5),
  updateFailed(6),
  deleting(7),
  deleteFailed(8);

  const SyncState(this.code);
  final int code;
}

@freezed
class Status with _$Status {
  const factory Status.creating({required Info info}) = _Creating;
  const factory Status.editing({required Info info}) = _Editing;
}

@freezed
class Info with _$Info {
  const factory Info({
    DateTime? localDate,
    int? id,
    @Default(SyncState.writing) SyncState syncState,
    String? depName,
    String? orgName,
    String? formFiller,
    int? callNumber,
    String? jobTitle,
    String? qualifications,
    TaskType? taskType,
    int? staffNumber,
    int? averageSalary,
    @Default(['']) List<String> perks,
    String? docs,
  }) = _Info;
  factory Info.fromJson(Map<String, Object?> json) => _$InfoFromJson(json);
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
  List<String> _perks = [''];
  List<FocusNode> _perksNodes = [FocusNode()];
  bool _wasEditingPerk = false;
  String _docs = '';

  // final _info = Info();
  final _isSending = BehaviorSubject.seeded(false);
  final _infos = BehaviorSubject.seeded(<Info>[]);
  final _syncStates = BehaviorSubject.seeded(<SyncState>[]);
  final _status = BehaviorSubject.seeded(const Status.creating(info: Info()));
  final _perksLength = BehaviorSubject.seeded(['']);
  @override
  void initState() {
    _infos.listen((value) {
      _syncStates.sink.add(value.map((e) => e.syncState).toList());
    });
    _status.listen((value) {
      _perksLength.add(value.info.perks.toList());
    });
    _perksLength.listen((value) {
      _perks = value;
    });
    // _infos.add([]);
    _infos.add((StorageService.instance.getStringList('savedInfo') ?? []).map((e) {
      Map<String, dynamic> decoded = jsonDecode(e);
      print(decoded);
      return Info.fromJson(decoded);
    }).toList());
    super.initState();
  }

  Future<bool> _uploadEditing(final Info _info) async {
    try {
      _isSending.add(true);
      dynamic res = await supabase.from('info').update(
        {
          'form_filler': _info.formFiller,
          'average_salary': _info.averageSalary,
          'dep_name': _info.depName,
          'org_name': _info.orgName,
          'call_number': _info.callNumber,
          'job_title': _info.jobTitle,
          'qualifications': _info.qualifications,
          'task_type': _info.taskType?.code,
          'staff_number': _info.staffNumber,
          'perks': _info.perks,
          'docs': _info.docs,
        },
      ).match({'id': _info.id});
      // _info.id = (id.first['id'] as int);
      // _info.sent = true;
      _infos.sink.add([for (var e in _infos.value) e.id != _info.id ? e : _info.copyWith(syncState: SyncState.updated)]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('با موفقیت ویرایش شد✅'),
          duration: Duration(seconds: 10),
        ));
      }
      return true;
    } catch (e) {
      _infos.sink.add([for (var e in _infos.value) e.id != _info.id ? e : _info.copyWith(syncState: SyncState.updateFailed)]);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: SelectableText(e.toString())));
      return false;
    } finally {
      _saveToStorage();
      _isSending.add(false);
      // _status.add(const Status.creating(info: Info()));
    }
  }

  Future<bool> _uploadCreating(final Info _info) async {
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
          'task_type': _info.taskType?.code,
          'staff_number': _info.staffNumber,
          'perks': _info.perks,
          'docs': _info.docs,
        },
      ).select('id');
      // _info.id = (id.first['id'] as int);
      // _info.sent = true;
      _infos.sink.add([
        for (var e in _infos.value) e.localDate != _info.localDate ? e : _info.copyWith(syncState: SyncState.inserted, id: (id.first['id'] as int))
      ]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('با موفقیت ثبت شد✅'),
          duration: Duration(seconds: 10),
        ));
      }
      return true;
    } catch (e) {
      _infos.sink.add([for (var e in _infos.value) e.localDate != _info.localDate ? e : _info.copyWith(syncState: SyncState.insertFailed)]);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: SelectableText(e.toString())));
      return false;
    } finally {
      _saveToStorage();
      _isSending.add(false);
      // _status.add(const Status.creating(info: Info()));
    }
  }

  void _saveToStorage() {
    StorageService.instance.setStringList(
        'savedInfo',
        _infos.value.map((e) {
          String saving = jsonEncode(e.toJson());
          print(saving);
          return saving;
        }).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 223, 245, 252),
      body:
          //      Row(
          //   mainAxisAlignment: MainAxisAlignment.center,
          //   crossAxisAlignment: CrossAxisAlignment.center,
          //   children: [
          //     Container(
          //       color: Colors.red,
          //       constraints: BoxConstraints(maxWidth: 400),
          //       child: Column(
          //         mainAxisAlignment: MainAxisAlignment.center,
          //         crossAxisAlignment: CrossAxisAlignment.center,
          //         mainAxisSize: MainAxisSize.min,
          //         children: [
          //           Form(
          //             child: TextFormField(
          //               controller: TextEditingController(text: "afasfasfwerwerg"),
          //             ),
          //           )
          //         ],
          //       ),
          //     )
          //   ],
          // )

          Padding(
        padding: const EdgeInsets.fromLTRB(40, 0, 40, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(
              child: StreamBuilder<Status>(
                  initialData: const Status.creating(info: Info()),
                  stream: _status.stream,
                  builder: (context, snapshot) {
                    final _formKey = GlobalKey<FormState>();
                    var status = snapshot.data!;
                    _averageSalary = snapshot.data!.info.averageSalary ?? 0;
                    return Form(
                      key: _formKey,
                      child: Container(
                        decoration: BoxDecoration(
                            color: Colors.white, border: Border.all(width: 1, color: Colors.grey.shade300), borderRadius: BorderRadius.circular(25)),
                        padding: EdgeInsets.fromLTRB(25, 25, 25, 25),
                        constraints: BoxConstraints(maxWidth: 800),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: 20),
                            Text(
                              'اطلاعات نیروهای شرکتی دستگاه های اجرایی 1401',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, fontSize: 30),
                            ),
                            SizedBox(height: 40),
                            TextFormField(
                                style: TextStyle(fontSize: 22),
                                initialValue: status.info.orgName,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'عنوان موسسه الزامیست';
                                  }
                                },
                                decoration:
                                    InputDecoration(labelText: 'عنوان موسسه', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
                                onSaved: (v) {
                                  _orgName = v ?? '';
                                }),
                            SizedBox(height: 20),

                            TextFormField(
                                style: TextStyle(fontSize: 22),
                                initialValue: status.info.depName,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'نام واحد سازمانی تکمیل کننده اطلاعات الزامیست';
                                  }
                                },
                                decoration: InputDecoration(
                                    labelText: 'نام واحد سازمانی تکمیل کننده اطلاعات',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
                                onSaved: (v) {
                                  _depName = v ?? '';
                                }),
                            SizedBox(height: 20),

                            TextFormField(
                                style: TextStyle(fontSize: 22),
                                initialValue: status.info.formFiller,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'نام تکمیل کننده فرم الزامیست';
                                  }
                                },
                                decoration: InputDecoration(
                                    labelText: 'نام تکمیل کننده فرم', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
                                onSaved: (v) {
                                  _formFiller = v ?? '';
                                }),
                            SizedBox(height: 20),

                            TextFormField(
                                style: TextStyle(fontSize: 22),
                                initialValue: status.info.callNumber?.toString() ?? '',
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'شماره تماس الزامیست';
                                  }
                                },
                                textAlign: TextAlign.left,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                keyboardType: TextInputType.number,
                                decoration:
                                    InputDecoration(labelText: 'شماره تماس', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
                                onSaved: (v) {
                                  _callNumber = int.tryParse(v ?? '') ?? 0;
                                }),
                            SizedBox(height: 20),

                            TextFormField(
                                style: TextStyle(fontSize: 22),
                                initialValue: status.info.jobTitle,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'عنوان شغل الزامیست';
                                  }
                                },
                                decoration:
                                    InputDecoration(labelText: 'عنوان شغل', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
                                onSaved: (v) {
                                  _jobTitle = v ?? '';
                                }),
                            SizedBox(height: 20),

                            TextFormField(
                                style: TextStyle(fontSize: 22),
                                initialValue: status.info.qualifications,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'شرایط احراز تحصیلی یا تجربی الزامیست';
                                  }
                                },
                                decoration: InputDecoration(
                                    labelText: 'شرایط احراز تحصیلی یا تجربی', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
                                onSaved: (v) {
                                  _qualifications = v ?? '';
                                }),
                            SizedBox(height: 20),

                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(0, 0, 8, 4),
                                  child: Text(
                                    'نوع وظیفه',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ),
                                SegmentFormField(
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    initialValue: status.info.taskType,
                                    validator: (TaskType? value) {
                                      if (value != null) {
                                        return null;
                                      } else {
                                        return 'یک گزینه را انتخاب کنید';
                                      }
                                    },
                                    onSaved: (TaskType? v) {
                                      _taskType = v ?? TaskType.main;
                                    }),
                              ],
                            ),
                            SizedBox(height: 25),

                            TextFormField(
                                style: TextStyle(fontSize: 22),
                                initialValue: status.info.staffNumber?.toString() ?? '',
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'تعداد نیروها الزامیست';
                                  }
                                  var parsed = int.tryParse(value) ?? 0;
                                  if (parsed <= 0) {
                                    return 'تعداد نیروها باید بزرگتر از صفر باشد';
                                  }
                                },
                                // textAlign: TextAlign.left,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                    labelText: 'تعداد نیروها به نفر', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
                                onSaved: (v) {
                                  _staffNumber = int.tryParse(v ?? '') ?? 0;
                                }),
                            SizedBox(height: 20),

                            StatefulBuilder(builder: (context, setState) {
                              return TextFormField(
                                  onChanged: (v) {
                                    setState(
                                      () {
                                        _averageSalary = int.tryParse(v.replaceAll(',', '')) ?? 0;
                                      },
                                    );
                                  },
                                  style: TextStyle(fontSize: 22),
                                  initialValue: status.info.averageSalary?.toString() ?? '',
                                  //_averageSalary != 0 ? _averageSalary.toString().seRagham() : '', // status.info.averageSalary?.toString() ?? '',
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'میانگین حقوق و مزایای پرداختی به تومان (بدون حق عائله مندی) الزامیست';
                                    }
                                    var parsed = int.tryParse(value.replaceAll(',', '')) ?? 0;
                                    if (parsed <= 0) {
                                      return 'میانگین حقوق و مزایای پرداختی به تومان (بدون حق عائله مندی) باید بزرگتر از صفر باشد';
                                    }
                                  },
                                  // textAlign: TextAlign.left,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    CurrencyTextInputFormatter(enableNegative: false, name: '', symbol: '', decimalDigits: 0)
                                    // FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,3}')),
                                  ],
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                      counter: _averageSalary != 0 ? Text(_averageSalary.toString().toWord() + ' تومان') : null,
                                      suffixText: 'تومان',
                                      labelText: 'میانگین حقوق و مزایای پرداختی به تومان (بدون حق عائله مندی)',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
                                  onSaved: (v) {
                                    _averageSalary = int.tryParse((v ?? '').replaceAll(',', '')) ?? 0;
                                  });
                            }),
                            SizedBox(height: 20),

                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(0, 0, 8, 4),
                                  child: Text(
                                    'اقلام حقوق و مزایا با ذکر نام',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ),
                                StreamBuilder<List<String>>(
                                  stream: _perksLength.stream,
                                  initialData: status.info.perks,
                                  builder: (context, snapshot) {
                                    var _perksNodes = snapshot.data!.map((e) => FocusNode()).toList();
                                    SchedulerBinding.instance.addPostFrameCallback(
                                      (_) {
                                        if (_wasEditingPerk) {
                                          _perksNodes.last.requestFocus();
                                        }
                                      },
                                    );

                                    return Column(
                                      children: [
                                        for (int i = 0; i < snapshot.data!.length; i++)
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(0, 3, 0, 3),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                i == snapshot.data!.length - 1
                                                    ? ExcludeFocusTraversal(
                                                        child: IconButton(
                                                            onPressed: () {
                                                              _wasEditingPerk = true;
                                                              _perksNodes[i].unfocus();
                                                              _perksLength.add([..._perksLength.value, '']);
                                                            },
                                                            icon: const Icon(Icons.add)),
                                                      )
                                                    : ExcludeFocusTraversal(
                                                        child: IconButton(
                                                            onPressed: () {
                                                              _wasEditingPerk = false;
                                                              _perksNodes[i].unfocus();

                                                              _perksLength
                                                                  .add(_perksLength.value.whereNotIndexed((index, element) => index == i).toList());
                                                            },
                                                            icon: const Icon(Icons.delete_outlined)),
                                                      ),
                                                Expanded(
                                                  child: TextFormField(
                                                    focusNode: _perksNodes[i],
                                                    style: TextStyle(fontSize: 22),
                                                    onSaved: (newValue) {
                                                      _wasEditingPerk = false;
                                                      _perksNodes[i].unfocus();

                                                      _perks[i] = newValue ?? '';
                                                    },
                                                    initialValue: snapshot.data![i],
                                                    onEditingComplete: () {
                                                      _wasEditingPerk = true;
                                                      _perksNodes[i].unfocus();

                                                      _perksLength.add([..._perksLength.value, '']);
                                                    },
                                                    // controller: _controller.value,
                                                    decoration: InputDecoration(
                                                        prefixText: '${i + 1}.',
                                                        // labelText: "اقلام حقوق و مزایا با ذکر نام",
                                                        border: OutlineInputBorder(
                                                            borderRadius: snapshot.data!.length == 1
                                                                ? BorderRadius.circular(15)
                                                                : i == 0
                                                                    ? BorderRadius.only(
                                                                        topLeft: Radius.circular(15),
                                                                        topRight: Radius.circular(15),
                                                                        bottomLeft: Radius.circular(6),
                                                                        bottomRight: Radius.circular(6))
                                                                    : i == snapshot.data!.length - 1
                                                                        ? BorderRadius.only(
                                                                            bottomLeft: Radius.circular(15),
                                                                            bottomRight: Radius.circular(15),
                                                                            topLeft: Radius.circular(6),
                                                                            topRight: Radius.circular(6))
                                                                        : BorderRadius.circular(6))),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                            // ItemsFormField(

                            //     initialValue: status.info.perks,
                            //     validator: (List<String>? value) {
                            //       if (value == null || value.isEmpty || value.every((element) => element.trim().isEmpty)) {
                            //         return 'حداقل یک آیتم اضافه کنید';
                            //       } else {
                            //         return null;
                            //       }
                            //     },
                            //     decoration: const InputDecoration(labelText: 'اقلام حقوق و مزایا با ذکر نام'),
                            //     onSaved: (List<String>? v) {
                            //       _perks = v?.where((element) => element.trim().isNotEmpty).toList() ?? [''];
                            //     }),
                            SizedBox(height: 20),
                            TextFormField(
                                style: TextStyle(fontSize: 22),
                                initialValue: status.info.docs,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'مستندات قانونی پرداخت حقوق و مزایا الزامیست';
                                  }
                                },
                                decoration: InputDecoration(
                                    labelText: 'مستندات قانونی پرداخت حقوق و مزایا',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
                                onSaved: (v) {
                                  _docs = v ?? '';
                                }),
                            SizedBox(height: 20),
                            StreamBuilder<bool>(
                                stream: _isSending.stream,
                                initialData: false,
                                builder: (context, snapshot) {
                                  return ElevatedButton(
                                      style: ButtonStyle(
                                          shape: MaterialStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                                          padding: MaterialStatePropertyAll(EdgeInsets.fromLTRB(0, 25, 0, 25))),
                                      onPressed: snapshot.data == false
                                          ? () async {
                                              if (_formKey.currentState!.validate()) {
                                                _formKey.currentState!.save();
                                                _perks.removeWhere((element) => element.trim().isEmpty);
                                                _status.add(const Status.creating(info: Info()));

                                                await status.when(creating: (_) async {
                                                  final _info = Info(
                                                      id: null,
                                                      localDate: DateTime.now(),
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
                                                      syncState: SyncState.inserting);
                                                  _infos.sink.add([_info, ..._infos.value]);
                                                  var res = await _uploadCreating(_info);
                                                }, editing: (info) async {
                                                  final _info = Info(
                                                      id: info.id,
                                                      localDate: DateTime.now(),
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
                                                      syncState: SyncState.updating);
                                                  _infos.sink.add([for (var e in _infos.value) e.id != info.id ? e : _info]);
                                                  var res = await _uploadEditing(_info);
                                                });

                                                // StorageService.instance.setStringList(
                                                //     'savedInfo',
                                                //     _infos.value.map((e) {
                                                //       String saving = jsonEncode(e);
                                                //       print(saving);
                                                //       return saving;
                                                //     }).toList());
                                              }
                                            }
                                          : null,
                                      child: const Text('ثبت اطلاعات'));
                                }),
                          ],
                        ),
                      ),
                    );
                  }),
            ),
            SizedBox(width: 40),
            Expanded(
              child: ExcludeFocusTraversal(
                child: StreamBuilder<List<Info>>(
                    stream: _infos.stream,
                    initialData: const [],
                    builder: (context, snapshot) {
                      return Table(
                        children: [
                          TableRow(children: [
                            Text(''),
                            Text('وضعیت'),
                            Text('عنوان شغل (کار / حرفه)'),
                            Text('شرایط احراز تحصیلی یا تجربی'),
                            Text('نوع وظیفه'),
                            Text('تعداد نیروها به نفر'),
                            Text('میانگین حقوق و مزایای پرداختی به تومان'),
                            Text('اقلام حقوق و مزایا با ذکر نام'),
                            Text('مستندات قانونی پرداخت حقوق و مزایا'),
                          ]),
                          ...snapshot.data!.mapIndexed((index, e) =>
                              TableRow(decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade50)), children: [
                                TableCell(
                                    verticalAlignment: TableCellVerticalAlignment.fill,
                                    child: StreamBuilder<bool>(
                                        initialData: false,
                                        stream: _isSending.stream,
                                        builder: (context, snapshot) {
                                          return IconButton(
                                            onPressed: snapshot.data!
                                                ? null
                                                : () {
                                                    _status.add(Status.editing(info: e));
                                                  },
                                            icon: const Icon(Icons.edit),
                                            tooltip: 'ویرایش',
                                          );
                                        })),
                                TableCell(
                                    verticalAlignment: TableCellVerticalAlignment.fill,
                                    child: StreamBuilder<List<SyncState>>(
                                      stream: _syncStates.stream,
                                      initialData: null,
                                      builder: (context, snapshot) {
                                        if (snapshot.data == null) return const Text('');
                                        switch (snapshot.data![index]) {
                                          case SyncState.writing:
                                            return const Text('📝');

                                          case SyncState.inserting:
                                            return const Text('⌛');
                                          case SyncState.inserted:
                                            return const Text('✅');
                                          case SyncState.insertFailed:
                                            return Column(
                                              children: [
                                                const Text('⛔'),
                                                StreamBuilder<bool>(
                                                    stream: _isSending.stream,
                                                    builder: (context, snapshot) {
                                                      return ElevatedButton(
                                                          onPressed: snapshot.data == false ? () => _uploadCreating(e) : null,
                                                          child: const Text('تلاش مجدد'));
                                                    })
                                              ],
                                            );
                                          case SyncState.updating:
                                            return const Text('⌛');
                                          case SyncState.updated:
                                            return const Text('✅');
                                          case SyncState.updateFailed:
                                            return Column(
                                              children: [
                                                const Text('⛔'),
                                                StreamBuilder<bool>(
                                                    stream: _isSending.stream,
                                                    builder: (context, snapshot) {
                                                      return ElevatedButton(
                                                          onPressed: snapshot.data == false ? () => _uploadEditing(e) : null,
                                                          child: const Text('تلاش مجدد'));
                                                    })
                                              ],
                                            );
                                          case SyncState.deleting:
                                            return const Text('⌛');
                                          case SyncState.deleteFailed:
                                            throw UnimplementedError();
                                        }
                                      },
                                    )),
                                TableCell(
                                    verticalAlignment: TableCellVerticalAlignment.middle,
                                    child: Container(color: Colors.red, child: Text(e.orgName!))),
                                TableCell(verticalAlignment: TableCellVerticalAlignment.middle, child: Text(e.qualifications!)),
                                TableCell(verticalAlignment: TableCellVerticalAlignment.middle, child: Text(e.taskType!.label)),
                                TableCell(verticalAlignment: TableCellVerticalAlignment.middle, child: Text(e.staffNumber!.toString())),
                                TableCell(verticalAlignment: TableCellVerticalAlignment.middle, child: Text(e.averageSalary!.toString())),
                                TableCell(
                                    verticalAlignment: TableCellVerticalAlignment.middle,
                                    child: Text(e.perks.mapIndexed((index, q) => '${index + 1}_$q').join('\n'))),
                                TableCell(verticalAlignment: TableCellVerticalAlignment.middle, child: Text(e.docs!)),
                              ]))
                        ].toList(),
                      );
                    }),
              ),
            )
          ],
        ),
      ),
    );
  }
}
