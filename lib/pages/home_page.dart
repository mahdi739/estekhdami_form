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

@freezed
class Job with _$Job {
  const factory Job({required String title, required String qualifications}) = _Job;
  factory Job.fromJson(Map<String, Object?> json) => _$JobFromJson(json);
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
    // String? jobTitle,
    // String? qualifications,
    @Default([Job(title: '', qualifications: '')]) List<Job> jobs,
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
  bool _wasEditingJobs = false;
  String _docs = '';
  List<Job> _jobs = [Job(title: '', qualifications: '')];

  // final _info = Info();
  final _isSending = BehaviorSubject.seeded(false);
  final _infos = BehaviorSubject.seeded(<Info>[]);
  final _syncStates = BehaviorSubject.seeded(<SyncState>[]);
  final _status = BehaviorSubject.seeded(const Status.creating(info: Info()));
  final _perksStream = BehaviorSubject.seeded(['']);
  final _jobsStream = BehaviorSubject.seeded([Job(title: '', qualifications: '')]);

  @override
  void initState() {
    _infos.listen((value) {
      _syncStates.sink.add(value.map((e) => e.syncState).toList());
    });
    _status.listen((value) {
      _perksStream.add(value.info.perks.toList());
      _jobsStream.add(value.info.jobs.toList());
    });
    _jobsStream.listen((value) {
      _jobs = value;
    });
    _perksStream.listen((value) {
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

  Future _delete(final Info _info) async {
    try {
      _isSending.add(true);
      if (_info.id != null) {
        dynamic res = await supabase.from('info').delete().match({'id': _info.id});
      }

      _infos.sink.add(_infos.value.whereNot((element) => element.localDate == _info.localDate).toList());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('با موفقیت حذف شد✅'), duration: Duration(seconds: 10)));
      }
      return true;
    } catch (e) {
      _infos.sink.add([for (var e in _infos.value) e.localDate != _info.localDate ? e : _info.copyWith(syncState: SyncState.deleteFailed)]);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: SelectableText(e.toString()), duration: Duration(seconds: 10)));
      return false;
    } finally {
      _saveToStorage();
      _isSending.add(false);
      // _status.add(const Status.creating(info: Info()));
    }
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
          // 'job_title': _info.jobTitle,
          // 'qualifications': _info.qualifications,
          'jobs': _info.jobs.map((e) => jsonEncode(e.toJson())).toList(),
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
          // 'job_title': _info.jobTitle,
          // 'qualifications': _info.qualifications,
          'jobs': _info.jobs.map((e) => jsonEncode(e.toJson())).toList(),
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
    StorageService.instance.setStringList('savedInfo', _infos.value.map((e) => jsonEncode(e.toJson())).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 223, 245, 252),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 0, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
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
                            color: Colors.white,
                            // border: Border.all(width: 1, color: Colors.grey.shade300),
                            // borderRadius: BorderRadius.circular(25)
                          ),
                          padding: EdgeInsets.fromLTRB(25, 25, 25, 25),
                          constraints: BoxConstraints(maxWidth: 800),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'اطلاعات نیروهای شرکتی دستگاه های اجرایی 1401',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, fontSize: 24),
                              ),
                              SizedBox(height: 20),
                              TextFormField(
                                  style: TextStyle(fontSize: 16),
                                  initialValue: status.info.orgName,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'عنوان موسسه الزامیست';
                                    }
                                  },
                                  decoration: InputDecoration(
                                      contentPadding: EdgeInsets.fromLTRB(12, 0, 12, 0),
                                      labelText: 'عنوان موسسه',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
                                  onSaved: (v) {
                                    _orgName = v ?? '';
                                  }),
                              SizedBox(height: 20),
                              TextFormField(
                                  style: TextStyle(fontSize: 16),
                                  initialValue: status.info.depName,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'نام واحد سازمانی تکمیل کننده اطلاعات الزامیست';
                                    }
                                  },
                                  decoration: InputDecoration(
                                      contentPadding: EdgeInsets.fromLTRB(12, 0, 12, 0),
                                      labelText: 'نام واحد سازمانی تکمیل کننده اطلاعات',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
                                  onSaved: (v) {
                                    _depName = v ?? '';
                                  }),
                              SizedBox(height: 20),
                              TextFormField(
                                  style: TextStyle(fontSize: 16),
                                  initialValue: status.info.formFiller,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'نام تکمیل کننده فرم الزامیست';
                                    }
                                  },
                                  decoration: InputDecoration(
                                      contentPadding: EdgeInsets.fromLTRB(12, 0, 12, 0),
                                      labelText: 'نام تکمیل کننده فرم',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
                                  onSaved: (v) {
                                    _formFiller = v ?? '';
                                  }),
                              SizedBox(height: 20),
                              TextFormField(
                                  style: TextStyle(fontSize: 16),
                                  initialValue: status.info.callNumber?.toString() ?? '',
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'شماره تماس الزامیست';
                                    }
                                  },
                                  textAlign: TextAlign.left,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                      contentPadding: EdgeInsets.fromLTRB(12, 0, 12, 0),
                                      labelText: 'شماره تماس',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
                                  onSaved: (v) {
                                    _callNumber = int.tryParse(v ?? '') ?? 0;
                                  }),
                              SizedBox(height: 20),
                              StreamBuilder<List<Job>>(
                                stream: _jobsStream.stream,
                                initialData: status.info.jobs,
                                builder: (context, snapshot) {
                                  var _jobsNodes = snapshot.data!.map((e) => FocusNode()).toList();
                                  SchedulerBinding.instance.addPostFrameCallback(
                                    (_) {
                                      if (_wasEditingJobs) {
                                        _jobsNodes.last.requestFocus();
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
                                                            _wasEditingJobs = true;
                                                            _jobsNodes[i].unfocus();
                                                            _jobsStream.add([..._jobsStream.value, Job(title: '', qualifications: '')]);
                                                          },
                                                          icon: const Icon(Icons.add)),
                                                    )
                                                  : ExcludeFocusTraversal(
                                                      child: IconButton(
                                                          onPressed: () {
                                                            _wasEditingJobs = false;
                                                            _jobsNodes[i].unfocus();

                                                            _jobsStream
                                                                .add(_jobsStream.value.whereNotIndexed((index, element) => index == i).toList());
                                                          },
                                                          icon: const Icon(Icons.delete_outlined)),
                                                    ),
                                              Expanded(
                                                child: TextFormField(
                                                    style: TextStyle(fontSize: 16),
                                                    initialValue: status.info.jobs[i].title,
                                                    validator: (value) {
                                                      if (value == null || value.isEmpty) {
                                                        return 'عنوان شغل الزامیست';
                                                      }
                                                    },
                                                    decoration: InputDecoration(
                                                        contentPadding: EdgeInsets.fromLTRB(12, 0, 12, 0),
                                                        labelText: 'عنوان شغل',
                                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
                                                    onSaved: (v) {
                                                      _jobs[i] = _jobs[i].copyWith(title: v ?? '');
                                                    }),
                                              ),
                                              Expanded(
                                                child: TextFormField(
                                                    style: TextStyle(fontSize: 16),
                                                    initialValue: status.info.jobs[i].qualifications,
                                                    validator: (value) {
                                                      if (value == null || value.isEmpty) {
                                                        return 'شرایط احراز تحصیلی یا تجربی الزامیست';
                                                      }
                                                    },
                                                    decoration: InputDecoration(
                                                        contentPadding: EdgeInsets.fromLTRB(12, 0, 12, 0),
                                                        labelText: 'شرایط احراز تحصیلی یا تجربی',
                                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
                                                    onSaved: (v) {
                                                      _jobs[i] = _jobs[i].copyWith(qualifications: v ?? '');
                                                    }),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                              SizedBox(height: 15),
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
                              SizedBox(height: 20),
                              TextFormField(
                                  style: TextStyle(fontSize: 16),
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
                                  textAlign: TextAlign.left,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                      contentPadding: EdgeInsets.fromLTRB(12, 0, 12, 0),
                                      labelText: 'تعداد نیروها به نفر',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
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
                                    style: TextStyle(fontSize: 16),
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
                                    textAlign: TextAlign.left,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      CurrencyTextInputFormatter(enableNegative: false, name: '', symbol: '', decimalDigits: 0)
                                      // FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,3}')),
                                    ],
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                        contentPadding: EdgeInsets.fromLTRB(12, 0, 12, 0),
                                        counter: _averageSalary != 0 ? Text(_averageSalary.toString().toWord() + ' تومان') : null,
                                        suffixText: ' تومان',
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
                                    stream: _perksStream.stream,
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
                                                                _perksStream.add([..._perksStream.value, '']);
                                                              },
                                                              icon: const Icon(Icons.add)),
                                                        )
                                                      : ExcludeFocusTraversal(
                                                          child: IconButton(
                                                              onPressed: () {
                                                                _wasEditingPerk = false;
                                                                _perksNodes[i].unfocus();

                                                                _perksStream
                                                                    .add(_perksStream.value.whereNotIndexed((index, element) => index == i).toList());
                                                              },
                                                              icon: const Icon(Icons.delete_outlined)),
                                                        ),
                                                  Expanded(
                                                    child: TextFormField(
                                                      focusNode: _perksNodes[i],
                                                      style: TextStyle(fontSize: 16),
                                                      onSaved: (newValue) {
                                                        _wasEditingPerk = false;
                                                        _perksNodes[i].unfocus();

                                                        _perks[i] = newValue ?? '';
                                                      },
                                                      initialValue: snapshot.data![i],
                                                      onEditingComplete: () {
                                                        _wasEditingPerk = true;
                                                        _perksNodes[i].unfocus();

                                                        _perksStream.add([..._perksStream.value, '']);
                                                      },
                                                      // controller: _controller.value,
                                                      decoration: InputDecoration(
                                                          contentPadding: EdgeInsets.fromLTRB(12, 0, 12, 0),
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
                              SizedBox(height: 20),
                              TextFormField(
                                  style: TextStyle(fontSize: 16),
                                  initialValue: status.info.docs,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'مستندات قانونی پرداخت حقوق و مزایا الزامیست';
                                    }
                                  },
                                  decoration: InputDecoration(
                                      contentPadding: EdgeInsets.fromLTRB(12, 0, 12, 0),
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
                                    bool showCancel = snapshot.data! == false && status.info.localDate != null;
                                    return Row(
                                      children: [
                                        Expanded(
                                          child: Padding(
                                            padding: EdgeInsets.fromLTRB(showCancel ? 3 : 0, 0, 0, 0),
                                            child: ElevatedButton(
                                                style: ButtonStyle(
                                                    shape: MaterialStatePropertyAll(RoundedRectangleBorder(
                                                        borderRadius: showCancel
                                                            ? BorderRadius.only(
                                                                topRight: Radius.circular(17),
                                                                bottomRight: Radius.circular(17),
                                                                bottomLeft: Radius.circular(5),
                                                                topLeft: Radius.circular(5),
                                                              )
                                                            : BorderRadius.circular(17))),
                                                    padding: MaterialStatePropertyAll(EdgeInsets.fromLTRB(0, 15, 0, 15))),
                                                onPressed: snapshot.data == false
                                                    ? () async {
                                                        if (_formKey.currentState!.validate()) {
                                                          _formKey.currentState!.save();
                                                          _perks.removeWhere((element) => element.trim().isEmpty);
                                                          _jobs.removeWhere(
                                                              (element) => element.title.trim().isEmpty || element.qualifications.trim().isEmpty);
                                                          _status.add(const Status.creating(info: Info()));

                                                          await status.when(creating: (_) async {
                                                            final _info = Info(
                                                                id: null,
                                                                localDate: DateTime.now(),
                                                                orgName: _orgName,
                                                                depName: _depName,
                                                                formFiller: _formFiller,
                                                                jobs: _jobs,
                                                                // jobTitle: _jobTitle,
                                                                callNumber: _callNumber,
                                                                // qualifications: _qualifications,
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
                                                                jobs: _jobs,
                                                                // jobTitle: _jobTitle,
                                                                callNumber: _callNumber,
                                                                // qualifications: _qualifications,
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
                                                child: const Text('ثبت اطلاعات')),
                                          ),
                                        ),
                                        if (showCancel)
                                          Expanded(
                                              child: Padding(
                                            padding: EdgeInsets.fromLTRB(0, 0, showCancel ? 3 : 0, 0),
                                            child: Theme(
                                              data: Theme.of(context)
                                                  .copyWith(colorScheme: ColorScheme.fromSeed(seedColor: Color.fromARGB(255, 179, 38, 30))),
                                              child: ElevatedButton(
                                                child: Text('لغو'),
                                                onPressed: () {
                                                  _status.add(Status.creating(info: Info()));
                                                },
                                                style: ButtonStyle(
                                                    shape: MaterialStatePropertyAll(RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.only(
                                                      bottomLeft: Radius.circular(17),
                                                      topLeft: Radius.circular(17),
                                                      bottomRight: Radius.circular(5),
                                                      topRight: Radius.circular(5),
                                                    ))),
                                                    padding: MaterialStatePropertyAll(EdgeInsets.fromLTRB(0, 15, 0, 15))),
                                              ),
                                            ),
                                          )),
                                      ],
                                    );
                                  }),
                            ],
                          ),
                        ),
                      );
                    }),
              ),
            ),
            SizedBox(
              width: 20,
            ),
            Expanded(
              flex: 7,
              child: ExcludeFocusTraversal(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                    child: StreamBuilder<List<Info>>(
                        stream: _infos.stream,
                        initialData: const [],
                        builder: (context, snapshot) {
                          return Table(
                            // border: TableBorder.all(width: 0.5),
                            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                            children: [
                              TableRow(
                                  decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary,
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(color: Colors.grey)),
                                  children: [
                                    // Container(
                                    //   padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
                                    //   alignment: Alignment.topCenter,
                                    //   constraints: BoxConstraints(minHeight: 45),
                                    //   child: Text(
                                    //     'ویرایش',
                                    //     textAlign: TextAlign.center,
                                    //     style: TextStyle(color: Colors.white),
                                    //   ),
                                    // ),
                                    Container(
                                        padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
                                        alignment: Alignment.topCenter,
                                        constraints: BoxConstraints(minHeight: 45),
                                        child: Text(
                                          'وضعیت',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Colors.white),
                                        )),
                                    Container(
                                        padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
                                        alignment: Alignment.topCenter,
                                        constraints: BoxConstraints(minHeight: 45),
                                        child: Text(
                                          'عنوان موسسه',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Colors.white),
                                        )),
                                    Container(
                                        padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
                                        alignment: Alignment.topCenter,
                                        constraints: BoxConstraints(minHeight: 45),
                                        child: Text(
                                          'نام واحد سازمانی تکمیل کننده اطلاعات',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Colors.white),
                                        )),
                                    Container(
                                        padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
                                        alignment: Alignment.topCenter,
                                        constraints: BoxConstraints(minHeight: 45),
                                        child: Text(
                                          'نام تکمیل کننده فرم',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Colors.white),
                                        )),
                                    Container(
                                        padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
                                        alignment: Alignment.topCenter,
                                        constraints: BoxConstraints(minHeight: 45),
                                        child: Text(
                                          'شماره تماس',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Colors.white),
                                        )),

                                    Container(
                                        padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
                                        alignment: Alignment.topCenter,
                                        constraints: BoxConstraints(minHeight: 45),
                                        child: Text(
                                          'مشاغل',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Colors.white),
                                        )),
                                    // Container(
                                    //     padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
                                    //     alignment: Alignment.topCenter,
                                    //     constraints: BoxConstraints(minHeight: 45),
                                    //     child: Text(
                                    //       'شرایط احراز تحصیلی یا تجربی',
                                    //       textAlign: TextAlign.center,
                                    //       style: TextStyle(color: Colors.white),
                                    //     )),
                                    Container(
                                        padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
                                        alignment: Alignment.topCenter,
                                        constraints: BoxConstraints(minHeight: 45),
                                        child: Text(
                                          'نوع وظیفه',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Colors.white),
                                        )),
                                    Container(
                                        padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
                                        alignment: Alignment.topCenter,
                                        constraints: BoxConstraints(minHeight: 45),
                                        child: Text(
                                          'تعداد نیروها به نفر',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Colors.white),
                                        )),
                                    Container(
                                        padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
                                        alignment: Alignment.topCenter,
                                        constraints: BoxConstraints(minHeight: 45),
                                        child: Text(
                                          'میانگین حقوق و مزایای پرداختی به تومان',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Colors.white),
                                        )),
                                    Container(
                                        padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
                                        alignment: Alignment.topCenter,
                                        constraints: BoxConstraints(minHeight: 45),
                                        child: Text(
                                          'اقلام حقوق و مزایا با ذکر نام',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Colors.white),
                                        )),
                                    Container(
                                        padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
                                        alignment: Alignment.topCenter,
                                        constraints: BoxConstraints(minHeight: 45),
                                        child: Text(
                                          'مستندات قانونی پرداخت حقوق و مزایا',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Colors.white),
                                        )),
                                  ]),
                              ...snapshot.data!.mapIndexed((index, e) => TableRow(
                                      decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(15),
                                          border: Border.all(color: Colors.grey.shade300)),
                                      children: [
                                        // TableCell(
                                        //     child: StreamBuilder<bool>(
                                        //         initialData: false,
                                        //         stream: _isSending.stream,
                                        //         builder: (context, snapshot) {
                                        //           return OutlinedButton(
                                        //             style: ButtonStyle(
                                        //               shape: MaterialStateProperty.all(const CircleBorder()),
                                        //               backgroundColor: MaterialStateProperty.all(Colors.transparent),
                                        //               padding: MaterialStateProperty.all(const EdgeInsets.all(0)),
                                        //               side: MaterialStateProperty.all(BorderSide.none),
                                        //               minimumSize: MaterialStateProperty.all(Size.zero),
                                        //               fixedSize: MaterialStateProperty.all(const Size(60, 40)),
                                        //               // shadowColor: MaterialStateProperty.all(Colors.black.withOpacity(0.5)),
                                        //               overlayColor: MaterialStateProperty.all(Colors.black.withOpacity(0.07)),
                                        //               foregroundColor: MaterialStateProperty.all(Theme.of(context).colorScheme.onSecondaryContainer),
                                        //               // splashFactory: NoSplash.splashFactory,
                                        //               // overlayColor: MaterialStateProperty.all<Color>(Colors.transparent),
                                        //               alignment: Alignment.center,
                                        //               // foregroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                                        //               //   if (states.contains(MaterialState.pressed)) {
                                        //               //     return Theme.of(context).iconTheme.color!.withOpacity(0.5);
                                        //               //   } else {
                                        //               //     return Theme.of(context).iconTheme.color!;
                                        //               //   }
                                        //               // }),
                                        //             ),
                                        //             child: const Icon(Icons.edit),
                                        //             onPressed: snapshot.data!
                                        //                 ? null
                                        //                 : () {
                                        //                     _status.add(Status.editing(info: e));
                                        //                   },
                                        //           );
                                        //         })),
                                        Container(
                                            padding: EdgeInsets.fromLTRB(0, 10, 0, 10),
                                            alignment: Alignment.topCenter,
                                            constraints: BoxConstraints(minHeight: 65),
                                            child: StreamBuilder<List<SyncState>>(
                                              stream: _syncStates.stream,
                                              initialData: null,
                                              builder: (context, snapshot) {
                                                if (snapshot.data == null) return const Text('');
                                                late final Widget child;
                                                switch (snapshot.data![index]) {
                                                  case SyncState.writing:
                                                    child = const Icon(Icons.edit_note_rounded);
                                                    break;
                                                  case SyncState.inserting:
                                                    child = const Icon(Icons.hourglass_empty);
                                                    break;
                                                  case SyncState.inserted:
                                                    child = const Icon(Icons.check_circle, color: Colors.green);
                                                    break;
                                                  case SyncState.insertFailed:
                                                    child = Column(
                                                      children: [
                                                        const Icon(Icons.error, color: Colors.red),
                                                        StreamBuilder<bool>(
                                                            stream: _isSending.stream,
                                                            builder: (context, snapshot) {
                                                              return ElevatedButton(
                                                                  onPressed: snapshot.data == false ? () => _uploadCreating(e) : null,
                                                                  child: const Text('تلاش مجدد', textAlign: TextAlign.center));
                                                            })
                                                      ],
                                                    );
                                                    break;
                                                  case SyncState.updating:
                                                    child = const Icon(Icons.hourglass_empty);
                                                    break;
                                                  case SyncState.updated:
                                                    child = const Icon(Icons.check_circle, color: Colors.green);
                                                    break;
                                                  case SyncState.updateFailed:
                                                    child = Column(
                                                      children: [
                                                        const Icon(Icons.error, color: Colors.red),
                                                        StreamBuilder<bool>(
                                                            stream: _isSending.stream,
                                                            builder: (context, snapshot) {
                                                              return ElevatedButton(
                                                                  onPressed: snapshot.data == false ? () => _uploadEditing(e) : null,
                                                                  child: const Text('تلاش مجدد', textAlign: TextAlign.center));
                                                            })
                                                      ],
                                                    );
                                                    break;
                                                  case SyncState.deleting:
                                                    child = const Icon(Icons.hourglass_empty);
                                                    break;
                                                  case SyncState.deleteFailed:
                                                    child = Column(
                                                      children: [
                                                        const Icon(Icons.error, color: Colors.red),
                                                        StreamBuilder<bool>(
                                                            stream: _isSending.stream,
                                                            builder: (context, snapshot) {
                                                              return ElevatedButton(
                                                                  onPressed: snapshot.data == false ? () => _delete(e) : null,
                                                                  child: const Text('تلاش مجدد', textAlign: TextAlign.center));
                                                            })
                                                      ],
                                                    );
                                                    break;
                                                }
                                                return Column(children: [
                                                  // OutlinedButton(
                                                  //   style: ButtonStyle(
                                                  //     shape: MaterialStateProperty.all(const CircleBorder()),
                                                  //     backgroundColor: MaterialStateProperty.all(Colors.transparent),
                                                  //     padding: MaterialStateProperty.all(const EdgeInsets.all(0)),
                                                  //     side: MaterialStateProperty.all(BorderSide.none),
                                                  //     minimumSize: MaterialStateProperty.all(Size.zero),
                                                  //     fixedSize: MaterialStateProperty.all(const Size(60, 40)),
                                                  //     // shadowColor: MaterialStateProperty.all(Colors.black.withOpacity(0.5)),
                                                  //     overlayColor: MaterialStateProperty.all(Colors.black.withOpacity(0.07)),
                                                  //     foregroundColor: MaterialStateProperty.all(Theme.of(context).colorScheme.onSecondaryContainer),
                                                  //     // splashFactory: NoSplash.splashFactory,
                                                  //     // overlayColor: MaterialStateProperty.all<Color>(Colors.transparent),
                                                  //     alignment: Alignment.center,
                                                  //     // foregroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                                                  //     //   if (states.contains(MaterialState.pressed)) {
                                                  //     //     return Theme.of(context).iconTheme.color!.withOpacity(0.5);
                                                  //     //   } else {
                                                  //     //     return Theme.of(context).iconTheme.color!;
                                                  //     //   }
                                                  //     // }),
                                                  //   ),
                                                  //   child: const Icon(Icons.settings),
                                                  //   onPressed:
                                                  //       snapshot.data![index] == SyncState.inserting || snapshot.data![index] == SyncState.updating
                                                  //           ? null
                                                  //           : () {
                                                  //               final RenderBox overlay = Overlay.of(context)?.context.findRenderObject() as RenderBox;
                                                  //           showMenu(
                                                  //               context: context,
                                                  //               position: RelativeRect.fromRect(
                                                  //                   _tapPosition.value! & const Size(40, 40), // smaller rect, the touch area
                                                  //                   Offset.zero & overlay.size // Bigger rect, the entire screen
                                                  //                   ),
                                                  //               items: [
                                                  //                 if (onEdit != null) PopupMenuItem<int>(value: 0, child: Text("Edit")),
                                                  //                 if (onDelete != null) PopupMenuItem<int>(value: 1, child: Text("Delete")),
                                                  //               ]).then((value) async {
                                                  //             if (value == 0) {
                                                  //               onEdit?.call();
                                                  //             } else if (value == 1) {
                                                  //               onDelete?.call();
                                                  //             }
                                                  //           });
                                                  //               _status.add(Status.editing(info: e));
                                                  //             },
                                                  // ),
                                                  PopupMenuButton(
                                                    enabled: snapshot.data![index] != SyncState.inserting &&
                                                        snapshot.data![index] != SyncState.updating &&
                                                        snapshot.data![index] != SyncState.deleting,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                    itemBuilder: (context) => [
                                                      //if (controller.settingsService.sdkInt.val < 29)
                                                      const PopupMenuItem<int>(value: 0, child: Text("ویرایش")),
                                                      const PopupMenuItem<int>(value: 1, child: Text("حذف"))
                                                    ],
                                                    color: Colors.white,
                                                    icon: Icon(
                                                      Icons.settings,
                                                    ),
                                                    onSelected: (int value) {
                                                      if (value == 0) {
                                                        _status.add(Status.editing(info: e));
                                                      } else if (value == 1) {
                                                        _delete(e);
                                                      }
                                                    },
                                                  ),
                                                  child
                                                ]);
                                              },
                                            )),
                                        TableCell(
                                            verticalAlignment: TableCellVerticalAlignment.middle,
                                            child: Container(
                                                alignment: Alignment.center,
                                                constraints: BoxConstraints(minHeight: 45),
                                                child: Text(
                                                  e.orgName!,
                                                  textAlign: TextAlign.center,
                                                ))),
                                        TableCell(
                                            verticalAlignment: TableCellVerticalAlignment.middle,
                                            child: Container(
                                                alignment: Alignment.center,
                                                constraints: BoxConstraints(minHeight: 45),
                                                child: Text(
                                                  e.depName!,
                                                  textAlign: TextAlign.center,
                                                ))),
                                        TableCell(
                                            verticalAlignment: TableCellVerticalAlignment.middle,
                                            child: Container(
                                                alignment: Alignment.center,
                                                constraints: BoxConstraints(minHeight: 45),
                                                child: Text(
                                                  e.formFiller!,
                                                  textAlign: TextAlign.center,
                                                ))),
                                        TableCell(
                                            verticalAlignment: TableCellVerticalAlignment.middle,
                                            child: Container(
                                                alignment: Alignment.center,
                                                constraints: BoxConstraints(minHeight: 45),
                                                child: Text(
                                                  e.callNumber!.toString(),
                                                  textAlign: TextAlign.center,
                                                ))),
                                        // TableCell(
                                        //     verticalAlignment: TableCellVerticalAlignment.middle,
                                        //     child: Container(
                                        //         alignment: Alignment.center,
                                        //         constraints: BoxConstraints(minHeight: 45),
                                        //         child: Text(
                                        //           e.jobTitle!,
                                        //           textAlign: TextAlign.center,
                                        //         ))),
                                        TableCell(
                                            verticalAlignment: TableCellVerticalAlignment.middle,
                                            child: Container(
                                                alignment: Alignment.center,
                                                constraints: BoxConstraints(minHeight: 45),
                                                child: Text(
                                                  e.jobs
                                                      .mapIndexed((index, element) => '${index + 1}_${element.title}: ${element.qualifications}')
                                                      .join('\n'),
                                                  textAlign: TextAlign.center,
                                                ))),
                                        TableCell(
                                            verticalAlignment: TableCellVerticalAlignment.middle,
                                            child: Container(
                                                alignment: Alignment.center,
                                                constraints: BoxConstraints(minHeight: 45),
                                                child: Text(
                                                  e.taskType!.label,
                                                  textAlign: TextAlign.center,
                                                ))),
                                        TableCell(
                                            verticalAlignment: TableCellVerticalAlignment.middle,
                                            child: Container(
                                                alignment: Alignment.center,
                                                constraints: BoxConstraints(minHeight: 45),
                                                child: Text(
                                                  e.staffNumber!.toString(),
                                                  textAlign: TextAlign.center,
                                                ))),
                                        TableCell(
                                            verticalAlignment: TableCellVerticalAlignment.middle,
                                            child: Container(
                                                alignment: Alignment.center,
                                                constraints: BoxConstraints(minHeight: 45),
                                                child: Text(
                                                  e.averageSalary!.toString(),
                                                  textAlign: TextAlign.center,
                                                ))),
                                        TableCell(
                                            verticalAlignment: TableCellVerticalAlignment.middle,
                                            child: Container(
                                                alignment: Alignment.center,
                                                constraints: BoxConstraints(minHeight: 45),
                                                child: Text(
                                                  e.perks.mapIndexed((index, q) => '${index + 1}_$q').join('\n'),
                                                  textAlign: TextAlign.center,
                                                ))),
                                        TableCell(
                                            verticalAlignment: TableCellVerticalAlignment.middle,
                                            child: Container(
                                                alignment: Alignment.center,
                                                constraints: BoxConstraints(minHeight: 45),
                                                child: Text(
                                                  e.docs!,
                                                  textAlign: TextAlign.center,
                                                ))),
                                      ]))
                            ].toList(),
                          );
                        }),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
