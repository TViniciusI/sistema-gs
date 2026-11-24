import 'package:flutter/foundation.dart';
import 'package:gs_mobile/core/number_pt.dart';
import 'package:gs_mobile/data/calibration_catalog.dart';
import 'package:gs_mobile/data/calibration_math.dart';
import 'package:gs_mobile/data/client_store.dart';
import 'package:gs_mobile/data/models.dart';

enum CalibrationKind {
  volumetric,
  volumetricInverted,
  temperature,
  temperatureMesh,
  density,
  pressure,
  conductivity,
  telemetry,
}

enum CalibrationJobStatus { draft, inProgress, pendingReview, done }

CalibrationKind calibrationKindFrom(String? raw) {
  switch (raw) {
    case 'volumetricInverted':
    case 'volumetricaInvertida':
      return CalibrationKind.volumetricInverted;
    case 'temperature':
      return CalibrationKind.temperature;
    case 'temperatureMesh':
    case 'malha':
      return CalibrationKind.temperatureMesh;
    case 'density':
      return CalibrationKind.density;
    case 'pressure':
      return CalibrationKind.pressure;
    case 'conductivity':
    case 'condutividade':
      return CalibrationKind.conductivity;
    case 'telemetry':
      return CalibrationKind.telemetry;
    default:
      return CalibrationKind.volumetric;
  }
}

String calibrationKindLabel(CalibrationKind kind) {
  switch (kind) {
    case CalibrationKind.volumetric:
      return 'Volumétrica / vazão';
    case CalibrationKind.volumetricInverted:
      return 'Volumétrica invertida';
    case CalibrationKind.temperature:
      return 'Temperatura';
    case CalibrationKind.temperatureMesh:
      return 'Malha de temperatura';
    case CalibrationKind.density:
      return 'Densidade';
    case CalibrationKind.pressure:
      return 'Pressão';
    case CalibrationKind.conductivity:
      return 'Condutividade';
    case CalibrationKind.telemetry:
      return 'Telemetria';
  }
}

/// Unidades comuns por tipo de certificado / canal.
const calibrationLengthUnits = ['mm', 'cm', 'm'];
const calibrationTemperatureUnits = ['°C', 'K', '°F'];
const calibrationPressureUnits = ['bar', 'kPa', 'psi', 'mmH₂O', 'kgf/cm²'];
const calibrationDensityUnits = ['kg/m³', 'g/cm³', '°API'];
const calibrationConductivityUnits = ['µS/cm', 'mS/cm', 'S/m', 'µS/m', 'mS/m'];
const calibrationFlowUnits = ['L/min', 'm³/h', 'L/h', 'gpm'];
const calibrationVolumeUnits = ['L', 'm³', 'gal'];

String defaultMeasurementUnit(CalibrationKind kind) {
  switch (kind) {
    case CalibrationKind.temperature:
    case CalibrationKind.temperatureMesh:
      return '°C';
    case CalibrationKind.density:
      return 'kg/m³';
    case CalibrationKind.pressure:
      return 'bar';
    case CalibrationKind.conductivity:
      return 'µS/cm';
    case CalibrationKind.telemetry:
      return 'mm';
    case CalibrationKind.volumetric:
    case CalibrationKind.volumetricInverted:
      return 'L/min';
  }
}

List<String> suggestedMeasurementUnits(CalibrationKind kind) {
  switch (kind) {
    case CalibrationKind.temperature:
    case CalibrationKind.temperatureMesh:
    case CalibrationKind.density:
    case CalibrationKind.pressure:
      return [
        ...calibrationTemperatureUnits,
        ...calibrationLengthUnits,
        ...calibrationPressureUnits,
        ...calibrationDensityUnits,
      ];
    case CalibrationKind.conductivity:
      return calibrationConductivityUnits;
    case CalibrationKind.telemetry:
      return [...calibrationLengthUnits, ...calibrationTemperatureUnits];
    case CalibrationKind.volumetric:
    case CalibrationKind.volumetricInverted:
      return calibrationFlowUnits;
  }
}

List<String> suggestedTelemetryUnits(String channelKey) {
  if (channelKey == 'level') return calibrationLengthUnits;
  if (channelKey == 'temperature') return calibrationTemperatureUnits;
  return [
    ...calibrationLengthUnits,
    ...calibrationTemperatureUnits,
    ...calibrationPressureUnits,
  ];
}

String resolvedMeasurementUnit(CalibrationJob job) {
  final custom = job.measurementUnit.trim();
  if (custom.isNotEmpty) return custom;
  return defaultMeasurementUnit(job.kind);
}

class CalibrationLimits {
  const CalibrationLimits({
    this.maxRepeatabilityPct = 0.05,
    this.maxVolumetricErrorPct = 0.05,
    this.maxLinearityPct = 0.25,
    this.maxGenericError,
  });

  final double maxRepeatabilityPct;
  final double maxVolumetricErrorPct;
  final double maxLinearityPct;

  /// Erro máximo admissível na calibração genérica / temperatura / pressão (na unidade de medição).
  final double? maxGenericError;

  CalibrationLimits copyWith({
    double? maxRepeatabilityPct,
    double? maxVolumetricErrorPct,
    double? maxLinearityPct,
    double? maxGenericError,
    bool clearMaxGenericError = false,
  }) {
    return CalibrationLimits(
      maxRepeatabilityPct: maxRepeatabilityPct ?? this.maxRepeatabilityPct,
      maxVolumetricErrorPct:
          maxVolumetricErrorPct ?? this.maxVolumetricErrorPct,
      maxLinearityPct: maxLinearityPct ?? this.maxLinearityPct,
      maxGenericError: clearMaxGenericError
          ? null
          : (maxGenericError ?? this.maxGenericError),
    );
  }

  Map<String, dynamic> toJson() => {
    'maxRepeatabilityPct': maxRepeatabilityPct,
    'maxVolumetricErrorPct': maxVolumetricErrorPct,
    'maxLinearityPct': maxLinearityPct,
    if (maxGenericError != null) 'maxGenericError': maxGenericError,
  };

  factory CalibrationLimits.fromJson(Map<String, dynamic> json) {
    return CalibrationLimits(
      maxRepeatabilityPct: _d(json['maxRepeatabilityPct'], 0.05),
      maxVolumetricErrorPct: _d(json['maxVolumetricErrorPct'], 0.05),
      maxLinearityPct: _d(json['maxLinearityPct'], 0.25),
      maxGenericError: _dOrNull(json['maxGenericError']),
    );
  }
}

class VolumeRun {
  const VolumeRun({
    required this.id,
    this.objectVolume,
    this.standardVolume,
    this.density,
    this.temperature,
  });

  final String id;
  final double? objectVolume;
  final double? standardVolume;
  final double? density;
  final double? temperature;

  bool get isFilled => objectVolume != null && standardVolume != null;

  double? get factor => factorFor();

  double? get errorPercent => errorPercentFor();

  double? factorFor({bool inverted = false}) =>
      meterFactor(standardVolume, objectVolume, inverted: inverted);

  double? errorPercentFor({bool inverted = false}) =>
      volumetricErrorPercent(standardVolume, objectVolume, inverted: inverted);

  /// Erro relativo (Vi − Vc) / Vi — usado no orçamento de incerteza da planilha GS.
  double? relativeVolumeErrorFor() {
    final object = objectVolume;
    final standard = standardVolume;
    if (object == null || standard == null || object == 0) return null;
    return (object - standard) / object;
  }

  VolumeRun copyWith({
    double? objectVolume,
    double? standardVolume,
    double? density,
    double? temperature,
    bool clearObject = false,
    bool clearStandard = false,
  }) {
    return VolumeRun(
      id: id,
      objectVolume: clearObject ? null : (objectVolume ?? this.objectVolume),
      standardVolume: clearStandard
          ? null
          : (standardVolume ?? this.standardVolume),
      density: density ?? this.density,
      temperature: temperature ?? this.temperature,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (objectVolume != null) 'objectVolume': objectVolume,
    if (standardVolume != null) 'standardVolume': standardVolume,
    if (density != null) 'density': density,
    if (temperature != null) 'temperature': temperature,
  };

  factory VolumeRun.fromJson(Map<String, dynamic> json) {
    return VolumeRun(
      id: jsonText(json['id']).isEmpty ? _id() : jsonText(json['id']),
      objectVolume: _dOrNull(json['objectVolume']),
      standardVolume: _dOrNull(json['standardVolume']),
      density: _dOrNull(json['density']),
      temperature: _dOrNull(json['temperature']),
    );
  }
}

class RunSetResult {
  const RunSetResult({
    required this.factors,
    required this.errors,
    required this.meanFactor,
    required this.meanError,
    required this.worstError,
    required this.repeatability,
    required this.repeatabilityOk,
    required this.errorOk,
    required this.passed,
    required this.complete,
  });

  final List<double> factors;
  final List<double> errors;
  final double? meanFactor;
  final double? meanError;

  /// Corrida com maior |erro| — critério do cliente (Vibra): qualquer corrida
  /// acima do limite reprova, não a média.
  final double? worstError;
  final double? repeatability;
  final bool repeatabilityOk;
  final bool errorOk;
  final bool passed;
  final bool complete;
}

RunSetResult evaluateRunSet(
  List<VolumeRun> runs,
  CalibrationLimits limits, {
  bool inverted = false,
}) {
  final filled = [
    for (final run in runs)
      if (run.isFilled) run,
  ];
  final factors = [
    for (final run in filled)
      if (run.factorFor(inverted: inverted) != null)
        run.factorFor(inverted: inverted)!,
  ];
  final errors = [
    for (final run in filled)
      if (run.errorPercentFor(inverted: inverted) != null)
        run.errorPercentFor(inverted: inverted)!,
  ];
  final rep = repeatabilityPercent(factors);
  final meanF = meanOrNull(factors);
  final meanE = meanOrNull(errors);
  double? worstE;
  for (final error in errors) {
    if (worstE == null || error.abs() > worstE.abs()) worstE = error;
  }
  final repOk = withinLimit(rep, limits.maxRepeatabilityPct);
  // Aceitável = TODAS as corridas ≤ limite. Média sozinha aprovava 0,05 + 0,01
  // com limite 0,04 e a Vibra manda refazer o serviço nesses casos.
  final errOk = errors.isNotEmpty &&
      errors.every((error) => withinLimit(error, limits.maxVolumetricErrorPct));
  final complete = filled.length >= 2 && filled.length == runs.length;
  return RunSetResult(
    factors: factors,
    errors: errors,
    meanFactor: meanF,
    meanError: meanE,
    worstError: worstE,
    repeatability: rep,
    repeatabilityOk: repOk,
    errorOk: errOk,
    passed: complete && repOk && errOk,
    complete: complete,
  );
}

class ConferenceAttempt {
  const ConferenceAttempt({
    required this.id,
    required this.createdAt,
    required this.runs,
    this.meterFactorApplied,
  });

  final String id;
  final DateTime createdAt;
  final List<VolumeRun> runs;
  final double? meterFactorApplied;

  ConferenceAttempt copyWith({
    List<VolumeRun>? runs,
    double? meterFactorApplied,
  }) {
    return ConferenceAttempt(
      id: id,
      createdAt: createdAt,
      runs: runs ?? this.runs,
      meterFactorApplied: meterFactorApplied ?? this.meterFactorApplied,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'runs': [for (final run in runs) run.toJson()],
    if (meterFactorApplied != null) 'meterFactorApplied': meterFactorApplied,
  };

  factory ConferenceAttempt.fromJson(Map<String, dynamic> json) {
    return ConferenceAttempt(
      id: jsonText(json['id']).isEmpty ? _id() : jsonText(json['id']),
      createdAt:
          DateTime.tryParse(jsonText(json['createdAt'])) ?? DateTime.now(),
      runs: _runs(json['runs']),
      meterFactorApplied: _dOrNull(json['meterFactorApplied']),
    );
  }
}

class FlowPoint {
  const FlowPoint({
    required this.id,
    this.flowRate,
    this.flowUnit = 'L/min',
    this.oldMeterFactor = 1,
    this.verification = const [],
    this.conferences = const [],
  });

  final String id;
  final double? flowRate;
  final String flowUnit;
  final double oldMeterFactor;
  final List<VolumeRun> verification;
  final List<ConferenceAttempt> conferences;

  bool get hasReadings =>
      verification.any((run) => run.isFilled) ||
      conferences.any((item) => item.runs.any((run) => run.isFilled));

  RunSetResult verificationResult(
    CalibrationLimits limits, {
    bool inverted = false,
  }) => evaluateRunSet(verification, limits, inverted: inverted);

  bool hasActiveConference(CalibrationLimits limits, {bool inverted = false}) {
    final last = lastCompleteConference;
    if (last == null) return false;
    final filled = [
      for (final r in last.runs)
        if (r.isFilled) r,
    ];
    return filled.length >= 2 && filled.length == last.runs.length;
  }

  ConferenceAttempt? get lastConference =>
      conferences.isEmpty ? null : conferences.last;

  /// Última conferência com as 2 (ou N) corridas preenchidas — ignora rascunho vazio no fim.
  ConferenceAttempt? get lastCompleteConference {
    for (var i = conferences.length - 1; i >= 0; i--) {
      final attempt = conferences[i];
      final filled = [
        for (final r in attempt.runs)
          if (r.isFilled) r,
      ];
      if (filled.length >= 2 && filled.length == attempt.runs.length) {
        return attempt;
      }
    }
    return null;
  }

  RunSetResult? conferenceResult(
    ConferenceAttempt attempt,
    CalibrationLimits limits, {
    bool inverted = false,
  }) {
    final filled = [
      for (final r in attempt.runs)
        if (r.isFilled) r,
    ];
    if (filled.isEmpty) return null;
    return evaluateRunSet(attempt.runs, limits, inverted: inverted);
  }

  RunSetResult? lastConferenceResult(
    CalibrationLimits limits, {
    bool inverted = false,
  }) {
    final last = lastCompleteConference ?? lastConference;
    if (last == null) return null;
    return conferenceResult(last, limits, inverted: inverted);
  }

  bool conferenceRequired(CalibrationLimits limits, {bool inverted = false}) {
    final check = verificationResult(limits, inverted: inverted);
    return check.complete && !check.passed;
  }

  bool get conferenceDispensed {
    return false;
  }

  bool isApproved(CalibrationLimits limits, {bool inverted = false}) {
    final check = verificationResult(limits, inverted: inverted);
    if (check.passed) return true;
    // Usa a última conferência completa (não uma vazia aberta depois do OK).
    final last = lastConferenceResult(limits, inverted: inverted);
    if (last != null && last.complete) return last.passed;
    return false;
  }

  double? workingMeanFactor({bool inverted = false}) {
    final last = lastCompleteConference ?? lastConference;
    if (last != null && last.runs.any((r) => r.isFilled)) {
      final factors = [
        for (final run in last.runs)
          if (run.factorFor(inverted: inverted) != null)
            run.factorFor(inverted: inverted)!,
      ];
      if (factors.isNotEmpty) return meanOrNull(factors);
    }
    final factors = [
      for (final run in verification)
        if (run.factorFor(inverted: inverted) != null)
          run.factorFor(inverted: inverted)!,
    ];
    return meanOrNull(factors);
  }

  /// Recalcula o "Mf aplicado" de cada conferência a partir do fator antigo
  /// atual (ex.: usuário corrigiu o Mf depois de já ter lançado as corridas).
  FlowPoint recalculateAppliedFactors(
    CalibrationLimits limits, {
    bool inverted = false,
    int meterFactorDigits = defaultMeterFactorDigits,
  }) {
    if (conferences.isEmpty) return this;
    final digits = clampMeterFactorDigits(meterFactorDigits);
    final next = <ConferenceAttempt>[];
    for (var i = 0; i < conferences.length; i++) {
      double? applied;
      if (i == 0) {
        final mean = verificationResult(limits, inverted: inverted).meanFactor;
        applied = mean == null
            ? conferences[i].meterFactorApplied
            : roundMeterFactor(
                correctedMeterFactor(oldMeterFactor, mean),
                digits,
              );
      } else {
        final prev = next[i - 1];
        final prevApplied = prev.meterFactorApplied;
        final prevRes = conferenceResult(prev, limits, inverted: inverted);
        if (prevApplied == null) {
          applied = conferences[i].meterFactorApplied;
        } else if (prevRes != null &&
            prevRes.complete &&
            prevRes.passed) {
          applied = prevApplied;
        } else if (prevRes?.meanFactor != null) {
          applied = roundMeterFactor(
            correctedMeterFactor(prevApplied, prevRes!.meanFactor!),
            digits,
          );
        } else {
          applied = prevApplied;
        }
      }
      next.add(conferences[i].copyWith(meterFactorApplied: applied));
    }
    return copyWith(conferences: next);
  }

  /// Próximo fator a aplicar no medidor.
  /// Conferência aprovada: o fator aplicado nela é o que fica (não recalcula).
  /// Conferência reprovada: fator aplicado × fator médio da conferência.
  double? suggestedNewFactor(
    CalibrationLimits limits, {
    bool inverted = false,
    int meterFactorDigits = defaultMeterFactorDigits,
  }) {
    final digits = clampMeterFactorDigits(meterFactorDigits);
    final last = leftConference;
    if (last != null) {
      final index = conferences.indexOf(last);
      final applied = last.meterFactorApplied ?? _factorBeforeConference(
        index,
        limits,
        inverted: inverted,
        meterFactorDigits: digits,
      );
      final confRes = conferenceResult(last, limits, inverted: inverted);
      if (confRes != null && confRes.complete && confRes.passed) {
        return applied;
      }
      if (confRes?.meanFactor != null && applied != null) {
        return roundMeterFactor(
          correctedMeterFactor(applied, confRes!.meanFactor!),
          digits,
        );
      }
    }
    final mean = verificationResult(limits, inverted: inverted).meanFactor;
    if (mean == null) return null;
    return roundMeterFactor(
      correctedMeterFactor(oldMeterFactor, mean),
      digits,
    );
  }

  /// Conferência que vale para "Valores Deixados": a última completa ou,
  /// se nenhuma estiver completa, a última com alguma corrida preenchida.
  ConferenceAttempt? get leftConference {
    final complete = lastCompleteConference;
    if (complete != null) return complete;
    for (var i = conferences.length - 1; i >= 0; i--) {
      if (conferences[i].runs.any((r) => r.isFilled)) return conferences[i];
    }
    return null;
  }

  /// Fator que fica no medidor (Valores Deixados do certificado).
  double leftMeterFactor(
    CalibrationLimits limits, {
    bool inverted = false,
    int meterFactorDigits = defaultMeterFactorDigits,
  }) {
    final conf = leftConference;
    if (conf == null) {
      return roundMeterFactor(oldMeterFactor, meterFactorDigits);
    }
    final raw = conf.meterFactorApplied ??
        _factorBeforeConference(
          conferences.indexOf(conf),
          limits,
          inverted: inverted,
          meterFactorDigits: meterFactorDigits,
        ) ??
        oldMeterFactor;
    return roundMeterFactor(raw, meterFactorDigits);
  }

  /// Fator que estava no medidor quando a conferência [index] começou,
  /// para conferências antigas salvas sem "Mf aplicado".
  double? _factorBeforeConference(
    int index,
    CalibrationLimits limits, {
    bool inverted = false,
    int meterFactorDigits = defaultMeterFactorDigits,
  }) {
    final digits = clampMeterFactorDigits(meterFactorDigits);
    if (index <= 0) {
      final mean = verificationResult(limits, inverted: inverted).meanFactor;
      if (mean == null) return null;
      return roundMeterFactor(
        correctedMeterFactor(oldMeterFactor, mean),
        digits,
      );
    }
    final prev = conferences[index - 1];
    final prevApplied = prev.meterFactorApplied ??
        _factorBeforeConference(
          index - 1,
          limits,
          inverted: inverted,
          meterFactorDigits: digits,
        );
    final prevRes = conferenceResult(prev, limits, inverted: inverted);
    if (prevApplied == null) return null;
    if (prevRes == null || prevRes.meanFactor == null) return prevApplied;
    if (prevRes.complete && prevRes.passed) return prevApplied;
    return roundMeterFactor(
      correctedMeterFactor(prevApplied, prevRes.meanFactor!),
      digits,
    );
  }

  FlowPoint withRunCount(int count) {
    return copyWith(
      verification: _padRuns(verification, count),
      conferences: [
        for (final attempt in conferences)
          attempt.runs.length > count
              ? attempt.copyWith(runs: _dropEmptyRunsAbove(attempt.runs, count))
              : attempt,
      ],
    );
  }

  FlowPoint copyWith({
    double? flowRate,
    String? flowUnit,
    double? oldMeterFactor,
    List<VolumeRun>? verification,
    List<ConferenceAttempt>? conferences,
    bool clearFlow = false,
  }) {
    return FlowPoint(
      id: id,
      flowRate: clearFlow ? null : (flowRate ?? this.flowRate),
      flowUnit: flowUnit ?? this.flowUnit,
      oldMeterFactor: oldMeterFactor ?? this.oldMeterFactor,
      verification: verification ?? this.verification,
      conferences: conferences ?? this.conferences,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (flowRate != null) 'flowRate': flowRate,
    'flowUnit': flowUnit,
    'oldMeterFactor': oldMeterFactor,
    'verification': [for (final run in verification) run.toJson()],
    'conferences': [for (final item in conferences) item.toJson()],
  };

  factory FlowPoint.fromJson(Map<String, dynamic> json) {
    return FlowPoint(
      id: jsonText(json['id']).isEmpty ? _id() : jsonText(json['id']),
      flowRate: _dOrNull(json['flowRate']),
      flowUnit: jsonText(json['flowUnit']).isEmpty
          ? 'L/min'
          : jsonText(json['flowUnit']),
      oldMeterFactor: _d(json['oldMeterFactor'], 1),
      verification: _runs(json['verification']),
      conferences: [
        for (final item in (json['conferences'] as List<dynamic>? ?? const []))
          ConferenceAttempt.fromJson(Map<String, dynamic>.from(item as Map)),
      ],
    );
  }
}

class GenericCycle {
  const GenericCycle({this.standard, this.instrument, this.temperature});

  final double? standard;
  final double? instrument;
  final double? temperature;

  bool get isFilled => standard != null && instrument != null;

  double? get error => isFilled ? instrument! - standard! : null;

  Map<String, dynamic> toJson() => {
    if (standard != null) 'standard': standard,
    if (instrument != null) 'instrument': instrument,
    if (temperature != null) 'temperature': temperature,
  };

  factory GenericCycle.fromJson(Map<String, dynamic> json) {
    return GenericCycle(
      standard: _dOrNull(json['standard']),
      instrument: _dOrNull(json['instrument']),
      temperature: _dOrNull(json['temperature']),
    );
  }

  GenericCycle copyWith({
    double? standard,
    double? instrument,
    double? temperature,
    bool clearTemperature = false,
  }) {
    return GenericCycle(
      standard: standard ?? this.standard,
      instrument: instrument ?? this.instrument,
      temperature: clearTemperature ? null : (temperature ?? this.temperature),
    );
  }
}

class GenericPoint {
  const GenericPoint({
    required this.id,
    this.label = '',
    this.oldFactor,
    this.newValue,
    this.cycles = const [],
    this.conferences = const [],
    this.isConference = false,
  });

  final String id;
  final String label;

  /// Fator (ou referência) que o equipamento tinha antes deste ponto.
  final double? oldFactor;

  /// Valor novo deixado / aplicado após a verificação deste ponto.
  final double? newValue;
  final List<GenericCycle> cycles;

  /// Corridas de conferência opcionais para transmissor / ponto genérico.
  final List<GenericCycle> conferences;

  /// Em temperatura: ciclo de conferência (após ajuste). Se algum ciclo
  /// marcado existir, a média do resultado usa só esses; senão, usa todos.
  final bool isConference;

  bool get hasReadings =>
      cycles.any((cycle) => cycle.isFilled) ||
      conferences.any((cycle) => cycle.isFilled) ||
      oldFactor != null ||
      newValue != null;

  List<double> get errors => [
    for (final cycle in cycles)
      if (cycle.error != null) cycle.error!,
  ];

  double? get meanError => meanOrNull(errors);

  List<double> get standardValues => [
    for (final cycle in cycles)
      if (cycle.isFilled && cycle.standard != null) cycle.standard!,
  ];

  double? get meanStandard => meanOrNull(standardValues);

  List<double> get instrumentValues => [
    for (final cycle in cycles)
      if (cycle.isFilled && cycle.instrument != null) cycle.instrument!,
  ];

  double? get meanInstrument => meanOrNull(instrumentValues);

  List<double> get temperatureValues => [
    for (final cycle in cycles)
      if (cycle.isFilled && cycle.temperature != null) cycle.temperature!,
  ];

  double? get meanTemperature => meanOrNull(temperatureValues);

  List<double> get conferenceErrors => [
    for (final cycle in conferences)
      if (cycle.error != null) cycle.error!,
  ];

  double? get meanConferenceError => meanOrNull(conferenceErrors);

  List<double> get conferenceStandardValues => [
    for (final cycle in conferences)
      if (cycle.isFilled && cycle.standard != null) cycle.standard!,
  ];

  double? get meanConferenceStandard => meanOrNull(conferenceStandardValues);

  List<double> get conferenceInstrumentValues => [
    for (final cycle in conferences)
      if (cycle.isFilled && cycle.instrument != null) cycle.instrument!,
  ];

  double? get meanConferenceInstrument =>
      meanOrNull(conferenceInstrumentValues);

  List<double> get conferenceTemperatureValues => [
    for (final cycle in conferences)
      if (cycle.isFilled && cycle.temperature != null) cycle.temperature!,
  ];

  double? get meanConferenceTemperature =>
      meanOrNull(conferenceTemperatureValues);

  bool isApproved(double? maxError) {
    if (meanError == null) return true;
    if (maxError == null || maxError <= 0) return true;
    final confE = meanConferenceError;
    if (confE != null) {
      return withinLimit(confE, maxError);
    }
    return withinLimit(meanError, maxError);
  }

  GenericPoint copyWith({
    String? label,
    double? oldFactor,
    double? newValue,
    List<GenericCycle>? cycles,
    List<GenericCycle>? conferences,
    bool? isConference,
    bool clearOldFactor = false,
    bool clearNewValue = false,
  }) {
    return GenericPoint(
      id: id,
      label: label ?? this.label,
      oldFactor: clearOldFactor ? null : (oldFactor ?? this.oldFactor),
      newValue: clearNewValue ? null : (newValue ?? this.newValue),
      cycles: cycles ?? this.cycles,
      conferences: conferences ?? this.conferences,
      isConference: isConference ?? this.isConference,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    if (oldFactor != null) 'oldFactor': oldFactor,
    if (newValue != null) 'newValue': newValue,
    if (isConference) 'isConference': true,
    'cycles': [for (final cycle in cycles) cycle.toJson()],
    if (conferences.isNotEmpty)
      'conferences': [for (final c in conferences) c.toJson()],
  };

  factory GenericPoint.fromJson(Map<String, dynamic> json) {
    return GenericPoint(
      id: jsonText(json['id']).isEmpty ? _id() : jsonText(json['id']),
      label: jsonText(json['label']),
      oldFactor: _dOrNull(json['oldFactor']),
      newValue: _dOrNull(json['newValue']),
      isConference: json['isConference'] == true,
      cycles: [
        for (final item in (json['cycles'] as List<dynamic>? ?? const []))
          GenericCycle.fromJson(Map<String, dynamic>.from(item as Map)),
      ],
      conferences: [
        for (final item in (json['conferences'] as List<dynamic>? ?? const []))
          GenericCycle.fromJson(Map<String, dynamic>.from(item as Map)),
      ],
    );
  }
}

const telemetryProcedureDefault =
    'Processo de calibração realizado por método direto de comparação das '
    'medidas geradas entre o instrumento sob prova e o padrão utilizado, com '
    'posterior apresentação dos dados. Cada padrão utilizado é inserido no '
    'tanque de armazenamento através do bocal de medição, indicando o valor '
    'real do processo, e neste momento, com o valor real do processo anotado, '
    'registra-se o valor apontado pelo instrumento sob prova, conforme '
    'orientações da ABTL, Procedimento Padrão para Aferição de Sistemas '
    'Automáticos de Medição de Nível, Revisão n° 02, de 09/04/2013 e API MPMS '
    'Chapter 3.1B Standard Practice for Level Measurement of Liquid '
    'Hydrocarbons in Stationary Tanks by Automatic Tank Gauging.';

const telemetryFieldConditions =
    'Atividades realizadas em campo, com os instrumentos instalados no tanque.';

const telemetryEquipmentTypeDefault = 'Medidor de Nível tipo Servo Operado';

class TelemetryTake {
  const TelemetryTake({this.standard, this.instrument});

  final double? standard;
  final double? instrument;

  bool get isFilled => standard != null && instrument != null;

  /// Erro absoluto |instrumento − padrão|, como nos certificados de tanque.
  double? get error {
    if (!isFilled) return null;
    return (instrument! - standard!).abs();
  }

  TelemetryTake copyWith({
    double? standard,
    double? instrument,
    bool clearStandard = false,
    bool clearInstrument = false,
  }) {
    return TelemetryTake(
      standard: clearStandard ? null : (standard ?? this.standard),
      instrument: clearInstrument ? null : (instrument ?? this.instrument),
    );
  }

  Map<String, dynamic> toJson() => {
    if (standard != null) 'standard': standard,
    if (instrument != null) 'instrument': instrument,
  };

  factory TelemetryTake.fromJson(Map<String, dynamic> json) {
    return TelemetryTake(
      standard: _dOrNull(json['standard']),
      instrument: _dOrNull(json['instrument']),
    );
  }
}

class TelemetryChannel {
  const TelemetryChannel({
    required this.id,
    required this.key,
    this.label = '',
    this.unit = '',
    this.found = const [],
    this.left = const [],
  });

  final String id;
  final String key;
  final String label;
  final String unit;
  final List<TelemetryTake> found;
  final List<TelemetryTake> left;

  bool get isLevel => key == 'level';

  bool get hasFound => found.any((take) => take.isFilled);

  bool get hasLeft => left.any((take) => take.isFilled);

  bool get hasReadings => hasFound || hasLeft;

  List<TelemetryTake> takes({required bool found}) => found ? this.found : left;

  List<double> errors({required bool found}) => [
    for (final take in takes(found: found))
      if (take.error != null) take.error!,
  ];

  double? meanError({required bool found}) => meanOrNull(errors(found: found));

  TelemetryChannel copyWith({
    String? label,
    String? unit,
    List<TelemetryTake>? found,
    List<TelemetryTake>? left,
  }) {
    return TelemetryChannel(
      id: id,
      key: key,
      label: label ?? this.label,
      unit: unit ?? this.unit,
      found: found ?? this.found,
      left: left ?? this.left,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'key': key,
    'label': label,
    'unit': unit,
    'found': [for (final take in found) take.toJson()],
    'left': [for (final take in left) take.toJson()],
  };

  factory TelemetryChannel.fromJson(Map<String, dynamic> json) {
    return TelemetryChannel(
      id: jsonText(json['id']).isEmpty ? _id() : jsonText(json['id']),
      key: jsonText(json['key']),
      label: jsonText(json['label']),
      unit: jsonText(json['unit']),
      found: _telemetryTakes(json['found']),
      left: _telemetryTakes(json['left']),
    );
  }
}

List<TelemetryTake> _telemetryTakes(dynamic raw) {
  return [
    for (final item in (raw as List<dynamic>? ?? const []))
      TelemetryTake.fromJson(Map<String, dynamic>.from(item as Map)),
  ];
}

List<TelemetryChannel> defaultTelemetryChannels() {
  return [
    TelemetryChannel(
      id: _id(),
      key: 'level',
      label: 'Nível',
      unit: 'mm',
      found: const [TelemetryTake(), TelemetryTake(), TelemetryTake()],
      left: const [TelemetryTake(), TelemetryTake(), TelemetryTake()],
    ),
    TelemetryChannel(
      id: _id(),
      key: 'temperature',
      label: 'Temperatura',
      unit: '°C',
      found: const [TelemetryTake()],
      left: const [TelemetryTake()],
    ),
  ];
}

class CalibrationStandard {
  const CalibrationStandard({
    required this.id,
    this.tag = '',
    this.description = '',
    this.certificate = '',
    this.validity = '',
    this.uncertainty = '',
    this.coverageK = '',
    this.resolution = '',
    this.stability = '',
    this.manufacturer = '',
    this.model = '',
    this.serialNumber = '',
    this.executant = '',
    this.calibrationDate = '',
    this.nominalValue = '',
    this.certifiedValue = '',
  });

  final String id;
  final String tag;
  final String description;
  final String certificate;
  final String validity;
  final String uncertainty;
  final String coverageK;
  final String resolution;

  /// Estabilidade do padrão (%), como na coluna da planilha Padrões.
  final String stability;
  final String manufacturer;
  final String model;
  final String serialNumber;
  final String executant;
  final String calibrationDate;

  /// Valor nominal da solução padrão (ex.: condutividade).
  final String nominalValue;

  /// Valor certificado da solução padrão (ex.: condutividade).
  final String certifiedValue;

  bool get isFilled =>
      tag.trim().isNotEmpty ||
      description.trim().isNotEmpty ||
      certificate.trim().isNotEmpty ||
      uncertainty.trim().isNotEmpty ||
      manufacturer.trim().isNotEmpty ||
      serialNumber.trim().isNotEmpty ||
      executant.trim().isNotEmpty ||
      nominalValue.trim().isNotEmpty ||
      certifiedValue.trim().isNotEmpty;

  /// Valor da incerteza do padrão para o certificado (não calcula U, k nem Veff).
  String get uncertaintyLabel {
    final direct = uncertainty.trim();
    if (direct.isNotEmpty) return direct;
    final match = RegExp(r'±\s*([^·]+)').firstMatch(description);
    return match?.group(1)?.trim() ?? '';
  }

  double? get uncertaintyPercent {
    final raw = uncertainty.trim().isNotEmpty
        ? uncertainty.trim()
        : uncertaintyLabel;
    if (raw.contains('°') ||
        RegExp(r'[a-zA-Z]').hasMatch(raw.replaceAll('%', ''))) {
      return null;
    }
    return parsePercentNumber(raw);
  }

  double get coverageKValue {
    final value = parseCalibNumber(coverageK);
    if (value == null || value <= 0) return 2;
    return value;
  }

  double? get stabilityPercent => parsePercentNumber(stability);

  CalibrationStandard copyWith({
    String? tag,
    String? description,
    String? certificate,
    String? validity,
    String? uncertainty,
    String? coverageK,
    String? resolution,
    String? stability,
    String? manufacturer,
    String? model,
    String? serialNumber,
    String? executant,
    String? calibrationDate,
    String? nominalValue,
    String? certifiedValue,
  }) {
    return CalibrationStandard(
      id: id,
      tag: tag ?? this.tag,
      description: description ?? this.description,
      certificate: certificate ?? this.certificate,
      validity: validity ?? this.validity,
      uncertainty: uncertainty ?? this.uncertainty,
      coverageK: coverageK ?? this.coverageK,
      resolution: resolution ?? this.resolution,
      stability: stability ?? this.stability,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      serialNumber: serialNumber ?? this.serialNumber,
      executant: executant ?? this.executant,
      calibrationDate: calibrationDate ?? this.calibrationDate,
      nominalValue: nominalValue ?? this.nominalValue,
      certifiedValue: certifiedValue ?? this.certifiedValue,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tag': tag,
    'description': description,
    'certificate': certificate,
    'validity': validity,
    'uncertainty': uncertainty,
    'coverageK': coverageK,
    'resolution': resolution,
    'stability': stability,
    'manufacturer': manufacturer,
    'model': model,
    'serialNumber': serialNumber,
    'executant': executant,
    'calibrationDate': calibrationDate,
    'nominalValue': nominalValue,
    'certifiedValue': certifiedValue,
  };

  factory CalibrationStandard.fromJson(Map<String, dynamic> json) {
    return CalibrationStandard(
      id: jsonText(json['id']).isEmpty ? _id() : jsonText(json['id']),
      tag: jsonText(json['tag']),
      description: jsonText(json['description']),
      certificate: jsonText(json['certificate']),
      validity: jsonText(json['validity']),
      uncertainty: jsonText(json['uncertainty']),
      coverageK: jsonText(json['coverageK']),
      resolution: jsonText(json['resolution']),
      stability: jsonText(json['stability']),
      manufacturer: jsonText(json['manufacturer']),
      model: jsonText(json['model']),
      serialNumber: jsonText(json['serialNumber'] ?? json['serial']),
      executant: jsonText(json['executant']),
      calibrationDate: jsonText(json['calibrationDate']),
      nominalValue: jsonText(json['nominalValue']),
      certifiedValue: jsonText(json['certifiedValue']),
    );
  }
}

String _withPercent(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return '';
  if (text.contains('%') ||
      text.contains('°') ||
      RegExp(r'[a-zA-Z]').hasMatch(text)) {
    return text;
  }
  return '$text%';
}

const coriolisCoefficientLabels = [
  'Flow Cal.',
  'KD',
  'SK20',
  'D1',
  'D2',
  'K1',
  'K2',
  'FC',
  'FD',
  'TC',
];

class CoriolisCoefficient {
  const CoriolisCoefficient({
    required this.id,
    required this.label,
    this.found = '',
    this.left = '',
  });

  final String id;
  final String label;
  final String found;
  final String left;

  String valueFor({required bool found}) {
    if (found) return this.found.trim();
    final left = this.left.trim();
    return left.isNotEmpty ? left : this.found.trim();
  }

  CoriolisCoefficient copyWith({String? label, String? found, String? left}) {
    return CoriolisCoefficient(
      id: id,
      label: label ?? this.label,
      found: found ?? this.found,
      left: left ?? this.left,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'found': found,
    'left': left,
  };

  factory CoriolisCoefficient.fromJson(Map<String, dynamic> json) {
    return CoriolisCoefficient(
      id: jsonText(json['id']).isEmpty ? _id() : jsonText(json['id']),
      label: jsonText(json['label']),
      found: jsonText(json['found'] ?? json['encontrado']),
      left: jsonText(json['left'] ?? json['deixado']),
    );
  }
}

class CalibrationJob {
  const CalibrationJob({
    required this.id,
    required this.kind,
    required this.createdAt,
    this.updatedAt,
    this.number = '',
    this.clientId = '',
    this.clientName = '',
    this.clientCnpj = '',
    this.clientAddress = '',
    this.equipmentId = '',
    this.equipmentTag = '',
    this.equipmentType = '',
    this.manufacturer = '',
    this.model = '',
    this.serialNumber = '',
    this.workingPrinciple = '',
    this.installLocation = '',
    this.systemType = '',
    this.systemId = '',
    this.systemTag = '',
    this.assemblyKind = '',
    this.presetTag = '',
    this.presetManufacturer = '',
    this.presetModel = '',
    this.presetSerial = '',
    this.instrumentRole = '',
    this.fluid = '',
    this.fluidDensityMin = '',
    this.fluidDensityMax = '',
    this.fluidViscosityMin = '',
    this.fluidViscosityMax = '',
    this.fluidDensityRefTemp = '',
    this.fluidViscosityRefTemp = '',
    this.fluidReferenceTemp = '',
    this.productDensity = '',
    this.productTemperature = '',
    this.site = '',
    this.procedure = 'Comparação direta',
    this.ambientTemp = '',
    this.humidity = '',
    this.pressure = '',
    this.technicianName = '',
    this.notes = '',
    this.measurementUncertainty = '',
    this.coverageFactor = '',
    this.effectiveDof = '',
    this.meterKFactorFound = '',
    this.meterKFactorLeft = '',
    this.instrumentResolution = '',
    this.tankType = '',
    this.concentrator = '',
    this.deviceId = '',
    this.fieldTechnicianName = '',
    this.runCount = 2,
    this.flowCount = 2,
    this.cycleCount = 3,
    this.measurementUnit = '',
    this.volumeUnit = 'L',
    this.meterFactorDigits = defaultMeterFactorDigits,
    this.limits = const CalibrationLimits(),
    this.points = const [],
    this.genericPoints = const [],
    this.telemetryChannels = const [],
    this.standards = const [],
    this.coriolisCoefficients = const [],
    this.status = CalibrationJobStatus.draft,
    this.calibrationDate = '',
    this.serviceRequester = '',
    this.orderNumber = '',
    this.osId = '',
    this.osNumber = '',
    this.calibrationSlotId = '',
  });

  final String id;
  final CalibrationKind kind;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String number;
  final String clientId;
  final String clientName;
  final String serviceRequester;
  final String orderNumber;
  final String clientCnpj;
  final String clientAddress;
  final String equipmentId;
  final String equipmentTag;
  final String equipmentType;
  final String manufacturer;
  final String model;
  final String serialNumber;
  final String workingPrinciple;
  final String installLocation;
  final String systemType;
  final String systemId;
  final String systemTag;
  final String assemblyKind;
  final String presetTag;
  final String presetManufacturer;
  final String presetModel;
  final String presetSerial;
  final String instrumentRole;
  final String fluid;
  final String fluidDensityMin;
  final String fluidDensityMax;
  final String fluidViscosityMin;
  final String fluidViscosityMax;
  final String fluidDensityRefTemp;
  final String fluidViscosityRefTemp;
  final String fluidReferenceTemp;

  /// Densidade do produto durante a calibração.
  final String productDensity;

  /// Temperatura do produto durante a calibração.
  final String productTemperature;
  final String site;
  final String procedure;
  final String ambientTemp;
  final String humidity;
  final String pressure;
  final String technicianName;
  final String notes;
  final String measurementUncertainty;
  final String coverageFactor;
  final String effectiveDof;

  /// Fator K do medidor sob calibração (Valores Encontrados).
  final String meterKFactorFound;

  /// Fator K do medidor sob calibração (Valores Deixados).
  final String meterKFactorLeft;
  final String instrumentResolution;
  final String tankType;
  final String concentrator;
  final String deviceId;
  final String fieldTechnicianName;
  final int runCount;
  final int flowCount;
  final int cycleCount;

  /// Unidade dos resultados (genérico / padrão do certificado).
  final String measurementUnit;

  /// Unidade dos volumes na volumétrica (Display Teste/Master).
  final String volumeUnit;

  /// Casas decimais do Mf (fator) na volumétrica — tela e certificado.
  final int meterFactorDigits;
  final CalibrationLimits limits;
  final List<FlowPoint> points;
  final List<GenericPoint> genericPoints;
  final List<TelemetryChannel> telemetryChannels;
  final List<CalibrationStandard> standards;
  final List<CoriolisCoefficient> coriolisCoefficients;
  final CalibrationJobStatus status;
  final String calibrationDate;
  final String osId;
  final String osNumber;
  final String calibrationSlotId;

  bool get isVolumetric =>
      kind == CalibrationKind.volumetric ||
      kind == CalibrationKind.volumetricInverted;

  bool get invertedVolumetric => kind == CalibrationKind.volumetricInverted;

  bool get isTelemetry => kind == CalibrationKind.telemetry;

  bool get isConductivity => kind == CalibrationKind.conductivity;

  bool get isCoriolis {
    final blob =
        '${workingPrinciple.toLowerCase()} ${equipmentType.toLowerCase()}';
    return blob.contains('coriolis');
  }

  bool get isPresetAssembly {
    final raw = assemblyKind.trim().toLowerCase();
    if (raw.contains('preset')) return true;
    if (raw.contains('transm')) return false;
    return presetTag.trim().isNotEmpty;
  }

  List<CoriolisCoefficient> coriolisFactorsOnCertificate({
    required bool found,
  }) {
    if (!isCoriolis) return const [];
    return [
      for (final item in coriolisCoefficients)
        if (item.valueFor(found: found).isNotEmpty) item,
    ];
  }

  String get title {
    if (number.trim().isNotEmpty) return number.trim();
    return calibrationKindLabel(kind);
  }

  String get subtitle {
    return [
      if (clientName.trim().isNotEmpty) clientName.trim(),
      if (systemTag.trim().isNotEmpty) systemTag.trim(),
      if (presetTag.trim().isNotEmpty) 'Preset ${presetTag.trim()}',
      if (equipmentTag.trim().isNotEmpty) 'TAG ${equipmentTag.trim()}',
      calibrationKindLabel(kind),
    ].join(' · ');
  }

  List<FlowPoint> get filledPoints => [
    for (final point in points)
      if (point.hasReadings) point,
  ];

  List<GenericPoint> get filledGenericPoints => [
    for (final point in genericPoints)
      if (point.hasReadings) point,
  ];

  /// Temperatura: há ciclo(s) marcados como conferência com medição.
  bool get hasTemperatureConferenceCycles => filledGenericPoints.any(
    (p) => p.isConference && p.cycles.any((c) => c.isFilled),
  );

  /// Ciclos que entram na média do resultado (certificado).
  /// Com conferência marcada: só esses. Sem: todos (ex.: PT100).
  List<GenericPoint> get temperatureResultCycles {
    final filled = filledGenericPoints;
    if (!hasTemperatureConferenceCycles) return filled;
    return [
      for (final p in filled)
        if (p.isConference && p.cycles.any((c) => c.isFilled)) p,
    ];
  }

  List<TelemetryChannel> get filledTelemetryChannels => [
    for (final channel in telemetryChannels)
      if (channel.hasReadings) channel,
  ];

  int get mfDigits => clampMeterFactorDigits(meterFactorDigits);

  List<double> meterFactors({required bool found}) {
    return [
      for (final point in filledPoints)
        found
            ? roundMeterFactor(point.oldMeterFactor, mfDigits)
            : point.leftMeterFactor(
                limits,
                inverted: invertedVolumetric,
                meterFactorDigits: mfDigits,
              ),
    ];
  }

  double? get linearity {
    final factors = meterFactors(found: false);
    return linearityPercent(factors);
  }

  /// Linearidade só existe com 2 ou mais vazões preenchidas.
  bool get linearityApplicable {
    return meterFactors(found: false).length >= 2;
  }

  bool get linearityOk =>
      !linearityApplicable || withinLimit(linearity, limits.maxLinearityPct);

  String get statusLabel {
    switch (status) {
      case CalibrationJobStatus.done:
        return 'Concluída';
      case CalibrationJobStatus.pendingReview:
        return 'Em análise';
      case CalibrationJobStatus.inProgress:
        return 'Em andamento';
      case CalibrationJobStatus.draft:
        return 'Rascunho';
    }
  }

  /// Tem leituras de vazão / genérico / telemetria.
  bool get hasMeasurements {
    if (points.any((p) => p.hasReadings)) return true;
    if (genericPoints.any((p) => p.hasReadings)) return true;
    if (telemetryChannels.any((c) => c.hasReadings)) return true;
    return false;
  }

  /// Quanto mais alto, mais “valioso” no sync (done+medições > rascunho vazio).
  int get integrityScore {
    var score = switch (status) {
      CalibrationJobStatus.done => 100,
      CalibrationJobStatus.pendingReview => 50,
      CalibrationJobStatus.inProgress => 20,
      CalibrationJobStatus.draft => 0,
    };
    if (hasMeasurements) score += 40;
    if (fluid.trim().isNotEmpty) score += 3;
    if (equipmentTag.trim().isNotEmpty) score += 2;
    if (serialNumber.trim().isNotEmpty) score += 2;
    return score;
  }

  /// Rascunho/andamento sem medições — típico dos “014x” fantasmas.
  bool get isEmptyGhost =>
      !hasMeasurements &&
      status != CalibrationJobStatus.done &&
      status != CalibrationJobStatus.pendingReview;

  /// [other] é claramente mais fraco (não deve sobrescrever este).
  bool isStrongerThan(CalibrationJob other) =>
      integrityScore > other.integrityScore;

  bool? get passed {
    if (isVolumetric) {
      if (filledPoints.isEmpty) return null;
      return filledPoints.every(
            (point) => point.isApproved(limits, inverted: invertedVolumetric),
          ) &&
          linearityOk;
    }
    if (isTelemetry) {
      if (filledTelemetryChannels.isEmpty) return null;
      return true;
    }
    if (filledGenericPoints.isEmpty) return null;
    final maxE = limits.maxGenericError;
    if (maxE != null && maxE > 0) {
      final points =
          (kind == CalibrationKind.temperature ||
              kind == CalibrationKind.temperatureMesh)
          ? temperatureResultCycles
          : filledGenericPoints;
      if (points.isEmpty) return null;
      return points.every((point) => point.isApproved(maxE));
    }
    return true;
  }

  String get resultLabel {
    final ok = passed;
    if (ok == null) return '—';
    return ok ? 'Aprovado' : 'Reprovado';
  }

  /// U da tabela de resultados (não é a incerteza do padrão).
  String get measurementULabel => _withPercent(measurementUncertainty);

  String get coverageKLabel {
    final text = coverageFactor.trim();
    if (text.isNotEmpty) return text;
    return measurementULabel.isEmpty ? '' : '2,00';
  }

  String get veffLabel {
    final text = effectiveDof.trim();
    if (text.isNotEmpty) return text;
    return measurementULabel.isEmpty ? '' : '∞';
  }

  UncertaintyBudget? uncertaintyBudget(FlowPoint point, {required bool found}) {
    if (!isVolumetric) return null;
    final runs = found
        ? [
            for (final run in point.verification)
              if (run.isFilled) run,
          ]
        : [
            for (final run
                in point.leftConference?.runs ?? const <VolumeRun>[])
              if (run.isFilled) run,
          ];
    final relativeErrors = [
      for (final run in runs)
        if (run.relativeVolumeErrorFor() != null) run.relativeVolumeErrorFor()!,
    ];
    final objectVolumes = [
      for (final run in runs)
        if (run.objectVolume != null) run.objectVolume!,
    ];
    CalibrationStandard? standard;
    for (final item in standards) {
      if (item.uncertaintyPercent != null) {
        standard = item;
        break;
      }
    }
    return volumetricUncertainty(
      relativeVolumeErrors: relativeErrors,
      objectVolumes: objectVolumes,
      standardExpandedPercent: standard?.uncertaintyPercent,
      standardK: standard?.coverageKValue ?? 2,
      standardResolutionLiters: parseCalibNumber(standard?.resolution ?? ''),
      instrumentResolutionLiters: parseCalibNumber(instrumentResolution),
      standardStabilityPercent: standard?.stabilityPercent,
    );
  }

  String resultULabel(FlowPoint point, {required bool found}) {
    if (measurementULabel.isNotEmpty) return measurementULabel;
    return uncertaintyBudget(point, found: found)?.uLabel ?? '';
  }

  String resultKLabel(FlowPoint point, {required bool found}) {
    if (coverageFactor.trim().isNotEmpty) return coverageFactor.trim();
    if (measurementULabel.isNotEmpty) return coverageKLabel;
    return uncertaintyBudget(point, found: found)?.kLabel ?? '';
  }

  String resultVeffLabel(FlowPoint point, {required bool found}) {
    if (effectiveDof.trim().isNotEmpty) return effectiveDof.trim();
    if (measurementULabel.isNotEmpty) return veffLabel;
    return uncertaintyBudget(point, found: found)?.veffLabel ?? '';
  }

  String get kindShortLabel {
    switch (kind) {
      case CalibrationKind.volumetric:
        return 'Vazão';
      case CalibrationKind.volumetricInverted:
        return 'Vazão invertida';
      case CalibrationKind.temperature:
        return 'Temperatura';
      case CalibrationKind.temperatureMesh:
        return 'Malha de temperatura';
      case CalibrationKind.density:
        return 'Densidade';
      case CalibrationKind.pressure:
        return 'Pressão';
      case CalibrationKind.conductivity:
        return 'Condutividade';
      case CalibrationKind.telemetry:
        return 'Telemetria';
    }
  }

  CalibrationJob copyWith({
    String? id,
    CalibrationKind? kind,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? number,
    String? clientId,
    String? clientName,
    String? clientCnpj,
    String? clientAddress,
    String? equipmentId,
    String? equipmentTag,
    String? equipmentType,
    String? manufacturer,
    String? model,
    String? serialNumber,
    String? workingPrinciple,
    String? installLocation,
    String? systemType,
    String? systemId,
    String? systemTag,
    String? assemblyKind,
    String? presetTag,
    String? presetManufacturer,
    String? presetModel,
    String? presetSerial,
    String? instrumentRole,
    String? fluid,
    String? fluidDensityMin,
    String? fluidDensityMax,
    String? fluidViscosityMin,
    String? fluidViscosityMax,
    String? fluidDensityRefTemp,
    String? fluidViscosityRefTemp,
    String? fluidReferenceTemp,
    String? productDensity,
    String? productTemperature,
    String? site,
    String? procedure,
    String? ambientTemp,
    String? humidity,
    String? pressure,
    String? technicianName,
    String? notes,
    String? measurementUncertainty,
    String? coverageFactor,
    String? effectiveDof,
    String? meterKFactorFound,
    String? meterKFactorLeft,
    String? instrumentResolution,
    String? tankType,
    String? concentrator,
    String? deviceId,
    String? fieldTechnicianName,
    int? runCount,
    int? flowCount,
    int? cycleCount,
    String? measurementUnit,
    String? volumeUnit,
    int? meterFactorDigits,
    CalibrationLimits? limits,
    List<FlowPoint>? points,
    List<GenericPoint>? genericPoints,
    List<TelemetryChannel>? telemetryChannels,
    List<CalibrationStandard>? standards,
    List<CoriolisCoefficient>? coriolisCoefficients,
    CalibrationJobStatus? status,
    String? calibrationDate,
    String? serviceRequester,
    String? orderNumber,
    String? osId,
    String? osNumber,
    String? calibrationSlotId,
  }) {
    return CalibrationJob(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      number: number ?? this.number,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      serviceRequester: serviceRequester ?? this.serviceRequester,
      orderNumber: orderNumber ?? this.orderNumber,
      clientCnpj: clientCnpj ?? this.clientCnpj,
      clientAddress: clientAddress ?? this.clientAddress,
      equipmentId: equipmentId ?? this.equipmentId,
      equipmentTag: equipmentTag ?? this.equipmentTag,
      equipmentType: equipmentType ?? this.equipmentType,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      serialNumber: serialNumber ?? this.serialNumber,
      workingPrinciple: workingPrinciple ?? this.workingPrinciple,
      installLocation: installLocation ?? this.installLocation,
      systemType: systemType ?? this.systemType,
      systemId: systemId ?? this.systemId,
      systemTag: systemTag ?? this.systemTag,
      assemblyKind: assemblyKind ?? this.assemblyKind,
      presetTag: presetTag ?? this.presetTag,
      presetManufacturer: presetManufacturer ?? this.presetManufacturer,
      presetModel: presetModel ?? this.presetModel,
      presetSerial: presetSerial ?? this.presetSerial,
      instrumentRole: instrumentRole ?? this.instrumentRole,
      fluid: fluid ?? this.fluid,
      fluidDensityMin: fluidDensityMin ?? this.fluidDensityMin,
      fluidDensityMax: fluidDensityMax ?? this.fluidDensityMax,
      fluidViscosityMin: fluidViscosityMin ?? this.fluidViscosityMin,
      fluidViscosityMax: fluidViscosityMax ?? this.fluidViscosityMax,
      fluidDensityRefTemp: fluidDensityRefTemp ?? this.fluidDensityRefTemp,
      fluidViscosityRefTemp:
          fluidViscosityRefTemp ?? this.fluidViscosityRefTemp,
      fluidReferenceTemp: fluidReferenceTemp ?? this.fluidReferenceTemp,
      productDensity: productDensity ?? this.productDensity,
      productTemperature: productTemperature ?? this.productTemperature,
      site: site ?? this.site,
      procedure: procedure ?? this.procedure,
      ambientTemp: ambientTemp ?? this.ambientTemp,
      humidity: humidity ?? this.humidity,
      pressure: pressure ?? this.pressure,
      technicianName: technicianName ?? this.technicianName,
      notes: notes ?? this.notes,
      measurementUncertainty:
          measurementUncertainty ?? this.measurementUncertainty,
      coverageFactor: coverageFactor ?? this.coverageFactor,
      effectiveDof: effectiveDof ?? this.effectiveDof,
      meterKFactorFound: meterKFactorFound ?? this.meterKFactorFound,
      meterKFactorLeft: meterKFactorLeft ?? this.meterKFactorLeft,
      instrumentResolution: instrumentResolution ?? this.instrumentResolution,
      tankType: tankType ?? this.tankType,
      concentrator: concentrator ?? this.concentrator,
      deviceId: deviceId ?? this.deviceId,
      fieldTechnicianName: fieldTechnicianName ?? this.fieldTechnicianName,
      runCount: runCount ?? this.runCount,
      flowCount: flowCount ?? this.flowCount,
      cycleCount: cycleCount ?? this.cycleCount,
      measurementUnit: measurementUnit ?? this.measurementUnit,
      volumeUnit: volumeUnit ?? this.volumeUnit,
      meterFactorDigits:
          clampMeterFactorDigits(meterFactorDigits ?? this.meterFactorDigits),
      limits: limits ?? this.limits,
      points: points ?? this.points,
      genericPoints: genericPoints ?? this.genericPoints,
      telemetryChannels: telemetryChannels ?? this.telemetryChannels,
      standards: standards ?? this.standards,
      coriolisCoefficients: coriolisCoefficients ?? this.coriolisCoefficients,
      status: status ?? this.status,
      calibrationDate: calibrationDate ?? this.calibrationDate,
      osId: osId ?? this.osId,
      osNumber: osNumber ?? this.osNumber,
      calibrationSlotId: calibrationSlotId ?? this.calibrationSlotId,
    );
  }

  Map<String, dynamic> toJson({bool slimMeasurements = false}) => {
    'id': id,
    'kind': kind.name,
    'createdAt': createdAt.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    'number': number,
    'clientId': clientId,
    'clientName': clientName,
    'clientCnpj': clientCnpj,
    'clientAddress': clientAddress,
    'equipmentId': equipmentId,
    'equipmentTag': equipmentTag,
    'equipmentType': equipmentType,
    'manufacturer': manufacturer,
    'model': model,
    'serialNumber': serialNumber,
    'workingPrinciple': workingPrinciple,
    'installLocation': installLocation,
    'systemType': systemType,
    'systemId': systemId,
    'systemTag': systemTag,
    'assemblyKind': assemblyKind,
    'presetTag': presetTag,
    'presetManufacturer': presetManufacturer,
    'presetModel': presetModel,
    'presetSerial': presetSerial,
    'instrumentRole': instrumentRole,
    'fluid': fluid,
    'fluidDensityMin': fluidDensityMin,
    'fluidDensityMax': fluidDensityMax,
    'fluidViscosityMin': fluidViscosityMin,
    'fluidViscosityMax': fluidViscosityMax,
    'fluidDensityRefTemp': fluidDensityRefTemp,
    'fluidViscosityRefTemp': fluidViscosityRefTemp,
    'fluidReferenceTemp': fluidReferenceTemp,
    'productDensity': productDensity,
    'productTemperature': productTemperature,
    'site': site,
    'procedure': procedure,
    'ambientTemp': ambientTemp,
    'humidity': humidity,
    'pressure': pressure,
    'technicianName': technicianName,
    'notes': notes,
    'measurementUncertainty': measurementUncertainty,
    'coverageFactor': coverageFactor,
    'effectiveDof': effectiveDof,
    'meterKFactorFound': meterKFactorFound,
    'meterKFactorLeft': meterKFactorLeft,
    'instrumentResolution': instrumentResolution,
    'tankType': tankType,
    'concentrator': concentrator,
    'deviceId': deviceId,
    'fieldTechnicianName': fieldTechnicianName,
    'runCount': runCount,
    'flowCount': flowCount,
    'cycleCount': cycleCount,
    'measurementUnit': measurementUnit,
    'volumeUnit': volumeUnit,
    'meterFactorDigits': mfDigits,
    'limits': limits.toJson(),
    'points': slimMeasurements
        ? const []
        : [for (final point in points) point.toJson()],
    'genericPoints': slimMeasurements
        ? const []
        : [for (final point in genericPoints) point.toJson()],
    'telemetryChannels': slimMeasurements
        ? const []
        : [for (final channel in telemetryChannels) channel.toJson()],
    'standards': [for (final item in standards) item.toJson()],
    'coriolisCoefficients': [
      for (final item in coriolisCoefficients) item.toJson(),
    ],
    'status': status.name,
    'calibrationDate': calibrationDate,
    'serviceRequester': serviceRequester,
    'orderNumber': orderNumber,
    'osId': osId,
    'osNumber': osNumber,
    'calibrationSlotId': calibrationSlotId,
  };

  factory CalibrationJob.fromJson(Map<String, dynamic> json) {
    final kind = calibrationKindFrom(json['kind'] as String?);
    final procedure = jsonText(json['procedure']);
    return CalibrationJob(
      id: jsonText(json['id']).isEmpty ? _id() : jsonText(json['id']),
      kind: kind,
      createdAt:
          DateTime.tryParse(jsonText(json['createdAt'])) ?? DateTime.now(),
      updatedAt: DateTime.tryParse(jsonText(json['updatedAt'])),
      number: jsonText(json['number']),
      clientId: jsonText(json['clientId']),
      clientName: jsonText(json['clientName']),
      serviceRequester: jsonText(
        json['serviceRequester'] ??
            json['solicitante'] ??
            json['solicitanteServico'],
      ),
      orderNumber: jsonText(
        json['orderNumber'] ?? json['pedido'] ?? json['numeroPedido'],
      ),
      clientCnpj: jsonText(json['clientCnpj']),
      clientAddress: jsonText(json['clientAddress']),
      equipmentId: jsonText(json['equipmentId']),
      equipmentTag: jsonText(json['equipmentTag']),
      equipmentType: jsonText(json['equipmentType']),
      manufacturer: jsonText(json['manufacturer']),
      model: jsonText(json['model']),
      serialNumber: jsonText(json['serialNumber']),
      workingPrinciple: jsonText(json['workingPrinciple']),
      installLocation: jsonText(json['installLocation']),
      systemType: jsonText(json['systemType']),
      systemId: jsonText(json['systemId']),
      systemTag: jsonText(json['systemTag']),
      assemblyKind: jsonText(json['assemblyKind']),
      presetTag: jsonText(json['presetTag']),
      presetManufacturer: jsonText(json['presetManufacturer']),
      presetModel: jsonText(json['presetModel']),
      presetSerial: jsonText(json['presetSerial']),
      instrumentRole: jsonText(json['instrumentRole']),
      fluid: jsonText(json['fluid']),
      fluidDensityMin: jsonText(json['fluidDensityMin']),
      fluidDensityMax: jsonText(json['fluidDensityMax']),
      fluidViscosityMin: jsonText(json['fluidViscosityMin']),
      fluidViscosityMax: jsonText(json['fluidViscosityMax']),
      fluidDensityRefTemp: jsonText(json['fluidDensityRefTemp']).isNotEmpty
          ? jsonText(json['fluidDensityRefTemp'])
          : jsonText(json['fluidReferenceTemp']),
      fluidViscosityRefTemp: jsonText(json['fluidViscosityRefTemp']),
      fluidReferenceTemp: jsonText(json['fluidReferenceTemp']),
      productDensity: jsonText(json['productDensity']),
      productTemperature: jsonText(json['productTemperature']),
      site: jsonText(json['site']),
      procedure: procedure.isEmpty ? _defaultProcedure(kind) : procedure,
      ambientTemp: jsonText(json['ambientTemp']),
      humidity: jsonText(json['humidity']),
      pressure: jsonText(json['pressure']),
      technicianName: jsonText(json['technicianName']),
      notes: jsonText(json['notes']),
      measurementUncertainty: jsonText(json['measurementUncertainty']),
      coverageFactor: jsonText(json['coverageFactor']),
      effectiveDof: jsonText(json['effectiveDof']),
      meterKFactorFound: jsonText(json['meterKFactorFound']).isEmpty
          ? jsonText(json['meterKFactor'])
          : jsonText(json['meterKFactorFound']),
      meterKFactorLeft: jsonText(json['meterKFactorLeft']),
      instrumentResolution: jsonText(json['instrumentResolution']),
      tankType: jsonText(json['tankType']),
      concentrator: jsonText(json['concentrator']),
      deviceId: jsonText(json['deviceId']),
      fieldTechnicianName: jsonText(json['fieldTechnicianName']),
      runCount: _i(json['runCount'], 2).clamp(2, 5),
      flowCount: _i(json['flowCount'], 2).clamp(1, 8),
      cycleCount: _i(json['cycleCount'], 3).clamp(1, 10),
      measurementUnit: jsonText(json['measurementUnit']).isEmpty
          ? defaultMeasurementUnit(kind)
          : jsonText(json['measurementUnit']),
      volumeUnit: jsonText(json['volumeUnit']).isEmpty
          ? 'L'
          : jsonText(json['volumeUnit']),
      meterFactorDigits: clampMeterFactorDigits(
        _i(json['meterFactorDigits'], defaultMeterFactorDigits),
      ),
      limits: json['limits'] is Map
          ? CalibrationLimits.fromJson(
              Map<String, dynamic>.from(json['limits'] as Map),
            )
          : const CalibrationLimits(),
      points: [
        for (final item in (json['points'] as List<dynamic>? ?? const []))
          FlowPoint.fromJson(Map<String, dynamic>.from(item as Map)),
      ],
      genericPoints: [
        for (final item
            in (json['genericPoints'] as List<dynamic>? ?? const []))
          GenericPoint.fromJson(Map<String, dynamic>.from(item as Map)),
      ],
      telemetryChannels: _readTelemetryChannels(json, kind),
      standards: [
        for (final item in (json['standards'] as List<dynamic>? ?? const []))
          CalibrationStandard.fromJson(Map<String, dynamic>.from(item as Map)),
      ],
      coriolisCoefficients: [
        for (final item
            in (json['coriolisCoefficients'] as List<dynamic>? ?? const []))
          CoriolisCoefficient.fromJson(Map<String, dynamic>.from(item as Map)),
      ],
      status: jsonText(json['status']) == 'done'
          ? CalibrationJobStatus.done
          : jsonText(json['status']) == 'pendingReview'
          ? CalibrationJobStatus.pendingReview
          : jsonText(json['status']) == 'inProgress'
          ? CalibrationJobStatus.inProgress
          : CalibrationJobStatus.draft,
      calibrationDate: jsonText(json['calibrationDate']),
      osId: jsonText(json['osId']),
      osNumber: jsonText(json['osNumber']),
      calibrationSlotId: jsonText(json['calibrationSlotId']),
    );
  }
}

CalibrationJob newCalibrationJob({
  required CalibrationKind kind,
  required String technicianName,
  int runCount = 2,
  int flowCount = 2,
}) {
  final now = DateTime.now();
  final cycles = kind == CalibrationKind.temperatureMesh ? 3 : 3;
  final telemetry = kind == CalibrationKind.telemetry;
  final conductivity = kind == CalibrationKind.conductivity;
  return CalibrationJob(
    id: _id(),
    kind: kind,
    createdAt: now,
    updatedAt: now,
    technicianName: technicianName,
    equipmentType: telemetry ? telemetryEquipmentTypeDefault : '',
    procedure: _defaultProcedure(kind),
    runCount: runCount,
    flowCount: flowCount,
    cycleCount: cycles,
    measurementUnit: defaultMeasurementUnit(kind),
    volumeUnit: 'L',
    points: [
      for (var i = 0; i < flowCount; i++)
        FlowPoint(
          id: _id(),
          verification: [
            for (var r = 0; r < runCount; r++) VolumeRun(id: _id()),
          ],
        ),
    ],
    genericPoints: telemetry
        ? const []
        : [
            for (var i = 0; i < 3; i++)
              GenericPoint(
                id: _id(),
                cycles: [for (var c = 0; c < cycles; c++) const GenericCycle()],
              ),
          ],
    telemetryChannels: telemetry ? defaultTelemetryChannels() : const [],
    standards: [
      if (conductivity)
        for (var i = 1; i <= 3; i++)
          CalibrationStandard(
            id: _id(),
            tag: 'Solução padrão $i',
            description: 'Solução de condutividade',
          )
      else ...[
        CalibrationStandard(id: _id()),
        if (telemetry) CalibrationStandard(id: _id()),
      ],
    ],
    status: CalibrationJobStatus.draft,
  );
}

/// Técnico do certificado: prioriza a equipe da OS.
/// Conta de desenvolvedor (ex.: Vinicius em testes) não entra como responsável.
String preferredCalibrationTechnician({
  required String osTechnicianName,
  required String userName,
  bool userIsDeveloper = false,
}) {
  final fromOs = osTechnicianName.trim();
  if (fromOs.isNotEmpty) return fromOs;
  if (userIsDeveloper) return '';
  final fromUser = userName.trim();
  final lower = fromUser.toLowerCase();
  if (lower.contains('vinicius') && lower.contains('magalh')) return '';
  if (lower == 'vinicius') return '';
  return fromUser;
}

CalibrationJob jobFromOsCalibrationSlot({
  required SavedOs os,
  required OsCalibrationSlot slot,
  required String technicianName,
}) {
  final kind = calibrationKindFrom(slot.kind);
  final resolvedTech = preferredCalibrationTechnician(
    osTechnicianName: os.technicianName,
    userName: technicianName,
  );
  final base = newCalibrationJob(kind: kind, technicianName: resolvedTech);
  final site = os.rdo.site.trim().isNotEmpty
      ? os.rdo.site
      : slot.installLocation;
  final client = ClientStore.instance.findMatch(
    cnpj: os.rdo.cnpj,
    name: os.rdo.client,
  );
  var job = base.copyWith(
    number: slot.certificateNumber,
    osId: os.id,
    osNumber: os.number,
    calibrationSlotId: slot.id,
    clientId: client?.id ?? '',
    clientName: os.rdo.client.trim().isNotEmpty
        ? os.rdo.client
        : (client?.name ?? ''),
    serviceRequester: client?.requester ?? '',
    clientCnpj: os.rdo.cnpj.trim().isNotEmpty
        ? os.rdo.cnpj
        : (client?.cnpj ?? ''),
    clientAddress: client?.addressLine ?? '',
    site: site,
    installLocation:
        slot.installLocation.trim().isNotEmpty &&
            isUsefulSystemLocal(slot.installLocation, site: site)
        ? slot.installLocation.trim()
        : '',
    systemType: slot.systemType.trim().isNotEmpty
        ? slot.systemType
        : os.rdo.systemType,
    systemId: slot.systemId,
    systemTag: slot.systemTag,
    assemblyKind: slot.assemblyKind,
    presetTag: slot.presetTag,
    presetManufacturer: slot.presetManufacturer,
    presetModel: slot.presetModel,
    presetSerial: slot.presetSerial,
    instrumentRole: slot.instrumentRole,
    equipmentId: slot.equipmentId,
    equipmentTag: slot.equipmentTag,
    equipmentType: slot.equipmentType,
    manufacturer: slot.manufacturer,
    model: slot.model,
    serialNumber: slot.serialNumber,
    workingPrinciple: slot.workingPrinciple,
    fluid: slot.product.trim().isNotEmpty ? slot.product : base.fluid,
  );
  job = promoteCalibrationJobInstrumentFromSlot(job, slot);
  // Sobressalente / slot sem TAG·N/S: não puxa medidor do cadastro.
  // Sem isso, abrir "sem calibração" herdava FT/N/S de outro certificado
  // e a lista passava a "Em andamento" com dados antigos.
  if (!slot.needsCadastro) {
    job = fillCalibrationJobInstrumentFromClient(job, client, slot: slot);
  }
  return enrichCalibrationJobFluidFromCatalog(job);
}

String _nonEmpty(String a, String b) => a.trim().isNotEmpty ? a : b;

/// Chave de identidade (TAG/N/S/preset): ignora maiúsculas e espaços extras.
/// Ex.: "PLACT - ILHA  3A" == "PLACT - ILHA 3A".
String calibrationIdentityKey(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// ILHA 3A / Plataforma 1 — local real do sistema (nunca "base" nem endereço).
bool looksLikeSystemInstallLocation(String value) {
  final t = calibrationIdentityKey(value);
  if (t.isEmpty) return false;
  if (RegExp(r'\bilha\s*[0-9]+[a-z]?\b').hasMatch(t)) return true;
  if (RegExp(r'\bplataforma\s*[0-9]+[a-z]?\b').hasMatch(t)) return true;
  return false;
}

/// Endereço da base/cliente — não é o "local do sistema" do certificado.
bool looksLikePostalAddress(String value, {String site = ''}) {
  final t = value.trim();
  if (t.isEmpty) return false;
  // Se o "site" da OS/cliente for a própria ilha (cadastrado em Locais),
  // não tratar ILHA/Plataforma como endereço postal.
  if (looksLikeSystemInstallLocation(t)) return false;
  final siteKey = calibrationIdentityKey(site);
  if (siteKey.isNotEmpty && calibrationIdentityKey(t) == siteKey) return true;
  if (RegExp(r'\bCEP\b', caseSensitive: false).hasMatch(t)) return true;
  if (RegExp(r'\d{5}-?\d{3}').hasMatch(t) && t.contains(',')) return true;
  return false;
}

/// "In Loco" / laboratório = modo do serviço, não local do sistema (ex.: Plataforma 1).
bool isGenericServicePlace(String value) {
  final n = calibrationIdentityKey(value).replaceAll('_', ' ').replaceAll('-', ' ');
  final compact = n.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.isEmpty) return true;
  const bad = {
    'in loco',
    'inloco',
    'laboratorio',
    'laboratório',
    'lab',
    'campo',
    'oficina',
    'banco de prova',
    'bancada',
    'sem local',
    'sem local do sistema',
    'nao informado',
    'não informado',
    'n/a',
    'na',
  };
  return bad.contains(compact);
}

/// Nome da base (BASPA) / site da OS — não é ilha/plataforma do cadastro.
bool looksLikeClientBaseAlias(
  String value, {
  String site = '',
  SavedClient? client,
  String clientName = '',
  String serviceRequester = '',
}) {
  final t = calibrationIdentityKey(value);
  if (t.isEmpty) return false;
  // ILHA/Plataforma no cadastro ou em "Locais" do cliente NÃO é alias de base.
  // Antes: sites=["ILHA 3A",…] fazia isUsefulSystemLocal=false → "Sem local".
  if (looksLikeSystemInstallLocation(value)) return false;
  if (looksLikePostalAddress(value, site: site)) return true;

  bool matchesAliasSource(String raw) {
    for (final part in raw.split(RegExp(r'[-–|/]'))) {
      final p = calibrationIdentityKey(part);
      if (p.length >= 3 && p == t) return true;
    }
    return calibrationIdentityKey(raw) == t;
  }

  if (client != null) {
    for (final s in client.sites) {
      // Locais do cliente às vezes listam as ilhas; não rejeitar ILHA por isso.
      if (looksLikeSystemInstallLocation(s)) continue;
      if (calibrationIdentityKey(s) == t) return true;
    }
    if (matchesAliasSource(client.name)) return true;
    if (client.requester.trim().isNotEmpty &&
        matchesAliasSource(client.requester)) {
      return true;
    }
  }
  // Mesmo sem SavedClient: nome/solicitante no job (ex.: "VIBRA … - BASPA").
  if (clientName.trim().isNotEmpty && matchesAliasSource(clientName)) {
    return true;
  }
  if (serviceRequester.trim().isNotEmpty &&
      matchesAliasSource(serviceRequester)) {
    return true;
  }
  return false;
}

bool isUsefulSystemLocal(
  String value, {
  String site = '',
  SavedClient? client,
  String clientName = '',
  String serviceRequester = '',
}) {
  final t = value.trim();
  if (t.isEmpty) return false;
  if (looksLikePostalAddress(t, site: site)) return false;
  if (isGenericServicePlace(t)) return false;
  if (looksLikeClientBaseAlias(
    t,
    site: site,
    client: client,
    clientName: clientName,
    serviceRequester: serviceRequester,
  )) {
    return false;
  }
  return true;
}

/// True quando o "local" gravado no certificado é na verdade a tag do preset
/// (ex.: FIQ 5B no lugar de ILHA 5B).
bool installLocationLooksLikePresetTag(CalibrationJob job, [String? raw]) {
  final loc = calibrationIdentityKey(raw ?? job.installLocation);
  if (loc.isEmpty) return false;
  final preset = calibrationIdentityKey(job.presetTag);
  if (preset.isNotEmpty && loc == preset) return true;
  final tag = calibrationIdentityKey(job.equipmentTag);
  if (tag.isNotEmpty && loc == tag) return true;
  return false;
}

/// Token de ilha/plataforma em TAG/preset/N/S (ex.: "3A", "5B").
String? islandTokenFromLabel(String raw) {
  final text = calibrationIdentityKey(raw);
  if (text.isEmpty) return null;
  final ilha = RegExp(r'\bilha\s*([0-9]+[a-z]?)\b').firstMatch(text);
  if (ilha != null) return ilha.group(1);
  // FIQ 3A / FT 5B / TE 4A / DE 5A — sufixo típico de ilha.
  final suffix = RegExp(
    r'\b(?:fiq|ft|te|de|tt|ti|pt)\s*([0-9]+[a-z]?)\b',
  ).firstMatch(text);
  if (suffix != null) return suffix.group(1);
  return null;
}

/// Normaliza rótulo de local ("ILHA  3A" → "ILHA 3A").
String normalizeInstallLocationLabel(String raw) {
  var t = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  t = t.replaceAllMapped(
    RegExp(r'\bilha\s*([0-9]+[a-z]?)\b', caseSensitive: false),
    (m) => 'ILHA ${m.group(1)!.toUpperCase()}',
  );
  return t;
}

/// Ordem natural de locais (ILHA 3A → 4A → 5A → 5B).
int compareInstallLocationLabels(String a, String b) {
  final aEmpty = a == 'Sem local do sistema';
  final bEmpty = b == 'Sem local do sistema';
  if (aEmpty != bEmpty) return aEmpty ? 1 : -1;
  final ta = islandTokenFromLabel(a);
  final tb = islandTokenFromLabel(b);
  if (ta != null && tb != null) {
    final na = int.tryParse(RegExp(r'\d+').firstMatch(ta)?.group(0) ?? '') ?? 0;
    final nb = int.tryParse(RegExp(r'\d+').firstMatch(tb)?.group(0) ?? '') ?? 0;
    if (na != nb) return na.compareTo(nb);
    final la = ta.replaceAll(RegExp(r'\d+'), '');
    final lb = tb.replaceAll(RegExp(r'\d+'), '');
    final byLetter = la.compareTo(lb);
    if (byLetter != 0) return byLetter;
  } else if (ta != null || tb != null) {
    return ta != null ? -1 : 1;
  }
  return a.toLowerCase().compareTo(b.toLowerCase());
}

/// Local da instalação do sistema no cadastro (nunca tag do preset).
String? catalogSystemInstallLocation(
  CalibrationJob job,
  SavedClient? client,
) {
  if (client == null) return null;
  final systems = client.resolvedSystems;
  if (systems.isEmpty) return null;

  ClientSystem? only(Iterable<ClientSystem> hits) {
    ClientSystem? found;
    for (final system in hits) {
      if (found != null && found.id != system.id) return null;
      found = system;
    }
    return found;
  }

  bool useful(ClientSystem? system) =>
      system != null &&
      isUsefulSystemLocal(
        system.installLocation,
        site: job.site,
        client: client,
        clientName: job.clientName,
        serviceRequester: job.serviceRequester,
      ) &&
      !installLocationLooksLikePresetTag(job, system.installLocation);

  String? labelOf(ClientSystem? system) {
    if (!useful(system)) return null;
    return normalizeInstallLocationLabel(system!.installLocation);
  }

  final byId = job.systemId.trim();
  if (byId.isNotEmpty) {
    for (final system in systems) {
      if (system.id == byId) {
        final label = labelOf(system);
        if (label != null) return label;
      }
    }
  }

  final preset = calibrationIdentityKey(job.presetTag);
  if (preset.isNotEmpty) {
    final byPreset = only([
      for (final system in systems)
        if (calibrationIdentityKey(system.assemblyTag) == preset ||
            calibrationIdentityKey(system.tag) == preset)
          system,
    ]);
    final label = labelOf(byPreset);
    if (label != null) return label;
  }

  final serial = calibrationIdentityKey(job.serialNumber);
  final tag = calibrationIdentityKey(job.equipmentTag);
  // N/S único: seguro. TAG sozinha se repete entre ilhas — só aceita se for 1.
  // Medidor + PT100 + densímetro (não só meters).
  // Compara com espaços normalizados (planilha VIBRA: "PLACT - ILHA  3A").
  if (serial.isNotEmpty) {
    final bySerial = only([
      for (final system in systems)
        if (system.instruments.any(
          (item) => calibrationIdentityKey(item.serialNumber) == serial,
        ))
          system,
    ]);
    final label = labelOf(bySerial);
    if (label != null) return label;
  }
  if (tag.isNotEmpty) {
    final byTag = only([
      for (final system in systems)
        if (system.instruments.any(
          (item) => calibrationIdentityKey(item.tag) == tag,
        ))
          system,
    ]);
    final label = labelOf(byTag);
    if (label != null) return label;
  }

  // Lista plana: só N/S único; TAG ambígua entre ilhas não escolhe a primeira.
  if (serial.isNotEmpty) {
    final fromSystems = <ClientSystem>[];
    final seen = <String>{};
    for (final item in client.equipment) {
      if (calibrationIdentityKey(item.serialNumber) != serial) continue;
      final sid = item.systemId.trim();
      if (sid.isEmpty || !seen.add(sid)) continue;
      for (final system in systems) {
        if (system.id == sid) fromSystems.add(system);
      }
    }
    final bySerialEq = only(fromSystems);
    final fromEq = labelOf(bySerialEq);
    if (fromEq != null) return fromEq;
    final locs = <String>{
      for (final item in client.equipment)
        if (calibrationIdentityKey(item.serialNumber) == serial)
          normalizeInstallLocationLabel(item.installLocation),
    }..removeWhere(
      (loc) =>
          !isUsefulSystemLocal(
            loc,
            site: job.site,
            client: client,
            clientName: job.clientName,
            serviceRequester: job.serviceRequester,
          ) ||
          installLocationLooksLikePresetTag(job, loc),
    );
    if (locs.length == 1) return locs.first;
  }

  // Último recurso: token de ilha no preset/TAG/N/S casa com um único local
  // do cadastro (FIQ 3A / PLACT - ILHA 3A → ILHA 3A).
  // NÃO usa job.installLocation: no bug antigo vinha tudo "ILHA 5B" e
  // escolheria a ilha errada.
  final tokens = <String>{
    if (islandTokenFromLabel(job.presetTag) != null)
      islandTokenFromLabel(job.presetTag)!,
    if (islandTokenFromLabel(job.equipmentTag) != null)
      islandTokenFromLabel(job.equipmentTag)!,
    if (islandTokenFromLabel(job.serialNumber) != null)
      islandTokenFromLabel(job.serialNumber)!,
  };
  for (final token in tokens) {
    final hits = <String>{
      for (final system in systems)
        if (useful(system) &&
            islandTokenFromLabel(system.installLocation) == token)
          normalizeInstallLocationLabel(system.installLocation),
      for (final system in systems)
        if (useful(system) &&
            (islandTokenFromLabel(system.assemblyTag) == token ||
                islandTokenFromLabel(system.tag) == token))
          normalizeInstallLocationLabel(system.installLocation),
    };
    if (hits.length == 1) return hits.first;
  }

  return null;
}

/// Infere ILHA a partir de TAG/preset/N/S mesmo sem cadastro carregado.
/// Ex.: FIQ 3A / FT 5B / "PLACT - ILHA  3A" → ILHA 3A / ILHA 5B.
/// Só inventa "ILHA …" com sufixo típico de ilha (número+letra).
String? inferInstallLocationFromInstrumentLabels(CalibrationJob job) {
  for (final raw in [job.serialNumber, job.presetTag, job.equipmentTag]) {
    final embedded = RegExp(
      r'\bilha\s*[0-9]+[a-z]?\b',
      caseSensitive: false,
    ).firstMatch(raw);
    if (embedded != null) {
      return normalizeInstallLocationLabel(embedded.group(0)!);
    }
  }
  for (final raw in [job.presetTag, job.equipmentTag]) {
    final key = calibrationIdentityKey(raw);
    // FIQ 3A / FT 5B / TE 4A / DE 5A — não inventa a partir de TAG genérica "FT".
    final m = RegExp(
      r'\b(?:fiq|ft|te|de|tt|ti)\s*([0-9]+[a-z])\b',
    ).firstMatch(key);
    if (m != null) {
      return 'ILHA ${m.group(1)!.toUpperCase()}';
    }
  }
  return null;
}

bool _isRealSystemLocal(
  CalibrationJob job,
  String raw, {
  SavedClient? client,
}) {
  return isUsefulSystemLocal(
        raw,
        site: job.site,
        client: client,
        clientName: job.clientName,
        serviceRequester: job.serviceRequester,
      ) &&
      !installLocationLooksLikePresetTag(job, raw);
}

/// Local do certificado no book/PDF.
/// Ordem: cadastro → sistema/equipamento → campo do job → inferência FIQ/ILHA.
/// Assim "BASPA" / vazio no job não engole ILHA 3A/4A/5B do cadastro.
String resolveCertificateInstallLocation(
  CalibrationJob job, {
  SavedClient? client,
  String systemLocal = '',
  String equipmentLocal = '',
}) {
  final catalog = catalogSystemInstallLocation(job, client)?.trim() ?? '';
  if (_isRealSystemLocal(job, catalog, client: client)) return catalog;

  for (final candidate in [systemLocal, equipmentLocal]) {
    if (_isRealSystemLocal(job, candidate, client: client)) {
      return normalizeInstallLocationLabel(candidate);
    }
  }

  final own = job.installLocation.trim();
  if (_isRealSystemLocal(job, own, client: client)) {
    return normalizeInstallLocationLabel(own);
  }

  // Sem cadastro / BASPA no job: ainda separa o book por FIQ 3A → ILHA 3A.
  final inferred = inferInstallLocationFromInstrumentLabels(job);
  if (inferred != null &&
      _isRealSystemLocal(job, inferred, client: client)) {
    return inferred;
  }
  return '';
}

/// Local do sistema (plataforma/ilha). Nunca endereço, "In Loco" nem tag do preset.
String calibrationSystemLocal(
  CalibrationJob job, {
  SavedClient? client,
  String systemLocal = '',
  String equipmentLocal = '',
}) {
  return resolveCertificateInstallLocation(
    job,
    client: client,
    systemLocal: systemLocal,
    equipmentLocal: equipmentLocal,
  );
}

/// Agrupa certificados do mesmo medidor/preset (adesivo e livro).
String calibrationMeterGroupKey(CalibrationJob job) {
  final preset = job.presetTag.trim().toLowerCase();
  if (preset.isNotEmpty) return 'preset:$preset';
  final sysId = job.systemId.trim();
  if (sysId.isNotEmpty) return 'sys:$sysId';
  final local = calibrationSystemLocal(job).toLowerCase();
  final tag = job.equipmentTag.trim().toLowerCase();
  if (local.isNotEmpty && tag.isNotEmpty) return 'loc:$local|tag:$tag';
  final serial = job.serialNumber.trim().toLowerCase();
  if (serial.isNotEmpty) return 'sn:$serial';
  if (tag.isNotEmpty) return 'tag:$tag';
  return 'job:${job.id}';
}

List<CalibrationJob> relatedCalibrationJobsForMeter(
  CalibrationJob job,
  Iterable<CalibrationJob> pool,
) {
  final key = calibrationMeterGroupKey(job);
  int certOrder(String raw) {
    final digits = RegExp(r'(\d+)(?!.*\d)').firstMatch(raw)?.group(1);
    return int.tryParse(digits ?? '') ?? 0;
  }

  final related = [
    for (final item in pool)
      if (calibrationMeterGroupKey(item) == key) item,
  ];
  related.sort((a, b) {
    int kindOrder(CalibrationKind k) {
      switch (k) {
        case CalibrationKind.volumetric:
        case CalibrationKind.volumetricInverted:
          return 0;
        case CalibrationKind.temperature:
        case CalibrationKind.temperatureMesh:
          return 1;
        case CalibrationKind.density:
          return 2;
        case CalibrationKind.pressure:
          return 3;
        case CalibrationKind.conductivity:
          return 4;
        case CalibrationKind.telemetry:
          return 5;
      }
    }

    final byKind = kindOrder(a.kind).compareTo(kindOrder(b.kind));
    if (byKind != 0) return byKind;
    final byNum = certOrder(a.number).compareTo(certOrder(b.number));
    if (byNum != 0) return byNum;
    return a.number.toLowerCase().compareTo(b.number.toLowerCase());
  });
  return related;
}

String _preferSystemLocal({
  required String preferred,
  required String current,
  required String site,
}) {
  if (isUsefulSystemLocal(preferred, site: site)) return preferred.trim();
  if (isUsefulSystemLocal(current, site: site)) return current.trim();
  return '';
}

bool calibrationJobInstrumentIncomplete(CalibrationJob job) {
  return job.equipmentTag.trim().isEmpty ||
      job.serialNumber.trim().isEmpty ||
      job.manufacturer.trim().isEmpty;
}

/// Densímetro / PT100 / malha ficam nos campos companheiros do slot — sobe para o job.
CalibrationJob promoteCalibrationJobInstrumentFromSlot(
  CalibrationJob job,
  OsCalibrationSlot slot,
) {
  switch (job.kind) {
    case CalibrationKind.density:
      return job.copyWith(
        equipmentTag: _nonEmpty(job.equipmentTag, slot.densimeterTag),
        manufacturer: _nonEmpty(job.manufacturer, slot.densimeterManufacturer),
        model: _nonEmpty(job.model, slot.densimeterModel),
        serialNumber: _nonEmpty(job.serialNumber, slot.densimeterSerial),
        workingPrinciple: _nonEmpty(
          job.workingPrinciple,
          slot.densimeterWorkingPrinciple,
        ),
        equipmentType: job.equipmentType.trim().isNotEmpty
            ? job.equipmentType
            : (slot.densimeterTag.trim().isNotEmpty ||
                      slot.densimeterSerial.trim().isNotEmpty
                  ? 'Densímetro'
                  : job.equipmentType),
        instrumentRole: job.instrumentRole.trim().isNotEmpty
            ? job.instrumentRole
            : ClientInstrumentRole.densimeter.name,
      );
    case CalibrationKind.temperature:
      return job.copyWith(
        equipmentTag: _nonEmpty(job.equipmentTag, slot.pt100Tag),
        manufacturer: _nonEmpty(job.manufacturer, slot.pt100Manufacturer),
        model: _nonEmpty(job.model, slot.pt100Model),
        serialNumber: _nonEmpty(job.serialNumber, slot.pt100Serial),
        workingPrinciple: _nonEmpty(
          job.workingPrinciple,
          slot.pt100WorkingPrinciple,
        ),
        equipmentType: job.equipmentType.trim().isNotEmpty
            ? job.equipmentType
            : (slot.pt100Tag.trim().isNotEmpty ||
                      slot.pt100Serial.trim().isNotEmpty
                  ? 'PT100'
                  : job.equipmentType),
        instrumentRole: job.instrumentRole.trim().isNotEmpty
            ? job.instrumentRole
            : ClientInstrumentRole.pt100.name,
      );
    case CalibrationKind.temperatureMesh:
      final tag = _nonEmpty(
        job.equipmentTag,
        _nonEmpty(slot.meshTag, slot.pt100Tag),
      );
      return job.copyWith(
        equipmentTag: tag,
        manufacturer: _nonEmpty(
          job.manufacturer,
          _nonEmpty(slot.meshManufacturer, slot.pt100Manufacturer),
        ),
        model: _nonEmpty(job.model, _nonEmpty(slot.meshModel, slot.pt100Model)),
        serialNumber: _nonEmpty(
          job.serialNumber,
          _nonEmpty(slot.meshSerialNumber, slot.pt100Serial),
        ),
        workingPrinciple: _nonEmpty(
          job.workingPrinciple,
          _nonEmpty(slot.meshWorkingPrinciple, slot.pt100WorkingPrinciple),
        ),
        equipmentType: job.equipmentType.trim().isNotEmpty
            ? job.equipmentType
            : (slot.meshEquipmentType.trim().isNotEmpty
                  ? slot.meshEquipmentType
                  : 'Malha de temperatura'),
        instrumentRole: job.instrumentRole.trim().isNotEmpty
            ? job.instrumentRole
            : ClientInstrumentRole.mesh.name,
      );
    default:
      return job;
  }
}

/// Se o instrumento ainda estiver vazio, puxa do cadastro do cliente (mesmo tipo).
/// Com [force]=true, atualiza mesmo certificado já preenchido (após planilha nova).
CalibrationJob fillCalibrationJobInstrumentFromClient(
  CalibrationJob job,
  SavedClient? client, {
  OsCalibrationSlot? slot,
  bool force = false,
}) {
  if (client == null) return job;
  final needsSystemPlace =
      job.systemType.trim().isEmpty ||
      job.systemId.trim().isEmpty ||
      !isUsefulSystemLocal(job.installLocation, site: job.site);
  if (!force &&
      !calibrationJobInstrumentIncomplete(job) &&
      job.equipmentId.trim().isNotEmpty &&
      !needsSystemPlace) {
    return job;
  }

  final placeForFilter =
      isUsefulSystemLocal(job.installLocation, site: job.site)
      ? job.installLocation
      : '';
  final pool = clientEquipmentForCalibration(
    equipment: client.equipment,
    kind: job.kind,
    usedIds: const {},
    installLocation: placeForFilter,
    systemType: job.systemType,
  );

  ClientEquipment? match;
  final slotEqId = slot?.equipmentId.trim() ?? '';
  final jobEqId = job.equipmentId.trim();
  final tagKey = _nonEmpty(
    slot?.equipmentTag ?? '',
    job.equipmentTag,
  ).trim().toLowerCase();
  final serialKey = _nonEmpty(
    slot?.serialNumber ?? '',
    job.serialNumber,
  ).trim().toLowerCase();

  // Pull forçado: TAG/N/S do slot (Excel) mandam sobre equipmentId velho.
  if (force && pool.isNotEmpty) {
    final byTag = <ClientEquipment>[];
    final bySerial = <ClientEquipment>[];
    for (final item in pool) {
      final t = item.tag.trim().toLowerCase();
      final s = item.serialNumber.trim().toLowerCase();
      if (tagKey.isNotEmpty && t == tagKey) byTag.add(item);
      if (serialKey.isNotEmpty && s == serialKey) bySerial.add(item);
    }
    if (bySerial.length == 1) {
      match = bySerial.first;
    } else if (byTag.length == 1) {
      match = byTag.first;
    }
  }

  // Num refresh explícito o slot acabou de ser relido do Excel, portanto seu
  // vínculo é mais atual que um equipmentId antigo salvo no certificado.
  if (match == null) {
    final wantedIds = force ? [slotEqId, jobEqId] : [jobEqId, slotEqId];
    for (final wantId in wantedIds) {
      if (wantId.isEmpty) continue;
      for (final item in client.equipment) {
        if (item.id == wantId) {
          // Id antigo de outro medidor (ex.: 0004 no certificado 0003) não
          // pode trocar TAG/N/S deste certificado.
          final itemTag = item.tag.trim().toLowerCase();
          final itemSerial = item.serialNumber.trim().toLowerCase();
          if (tagKey.isNotEmpty && itemTag.isNotEmpty && itemTag != tagKey) {
            continue;
          }
          if (serialKey.isNotEmpty &&
              itemSerial.isNotEmpty &&
              itemSerial != serialKey) {
            continue;
          }
          match = item;
          break;
        }
      }
      if (match != null) break;
    }
  }
  if (match != null) {
    return applyClientEquipmentToCalibrationJob(
      job,
      match,
      overwriteIdentity: force,
    );
  }
  if (pool.isEmpty) return job;

  final densTag = (slot?.densimeterTag ?? '').trim().toLowerCase();
  final ptTag = (slot?.pt100Tag ?? '').trim().toLowerCase();
  final meshTag = (slot?.meshTag ?? '').trim().toLowerCase();
  if (match == null) {
    for (final item in pool) {
      final t = item.tag.trim().toLowerCase();
      if (t.isEmpty) continue;
      if (tagKey.isNotEmpty && t == tagKey) {
        final itemSerial = item.serialNumber.trim().toLowerCase();
        if (serialKey.isNotEmpty &&
            itemSerial.isNotEmpty &&
            itemSerial != serialKey) {
          continue;
        }
        match = item;
        break;
      }
      if (densTag.isNotEmpty && t == densTag) {
        match = item;
        break;
      }
      if (ptTag.isNotEmpty && t == ptTag) {
        match = item;
        break;
      }
      if (meshTag.isNotEmpty && t == meshTag) {
        match = item;
        break;
      }
    }
  }

  // TAG ou N/S já identificam este certificado. Não inventa "o único"
  // medidor do local/sistema — era assim que o 0003 saía com o FT/N/S do 0004.
  final ownsIdentity = tagKey.isNotEmpty || serialKey.isNotEmpty;
  final systemId = job.systemId.trim();
  if (match == null && !ownsIdentity && systemId.isNotEmpty) {
    final atSystem = [
      for (final item in pool)
        if (item.systemId.trim() == systemId) item,
    ];
    // Só aceita se for o único medidor daquele sistema — nunca o "primeiro".
    if (atSystem.length == 1) {
      match = atSystem.first;
    }
  }

  if (match == null && pool.length == 1 && (force || !ownsIdentity)) {
    // Pull explícito com uma única linha do cadastro ainda corrige TAG/N/S.
    // No automático, certificado que já tem TAG ou N/S não herda esse único.
    match = pool.first;
  }

  // Um densímetro / PT100 no local + tipo já basta.
  if (match == null && !ownsIdentity) {
    final atPlace = [
      for (final item in pool)
        if ((job.systemType.trim().isEmpty ||
                item.systemType.trim().toLowerCase() ==
                    job.systemType.trim().toLowerCase()) &&
            (placeForFilter.trim().isEmpty ||
                item.installLocation.trim().toLowerCase() ==
                    placeForFilter.trim().toLowerCase()))
          item,
    ];
    if (atPlace.length == 1) match = atPlace.first;
  }

  if (match == null) {
    // Ainda sem match por id: tenta TAG/N/S em todo o cadastro (sem filtro de local).
    // serialKey já prioriza o slot — não usar o N/S contaminado do job.
    for (final item in client.equipment) {
      if (!clientEquipmentMatchesCalibrationKind(item, job.kind)) continue;
      final itemSerial = item.serialNumber.trim().toLowerCase();
      final itemTag = item.tag.trim().toLowerCase();
      if (serialKey.isNotEmpty && itemSerial == serialKey) {
        match = item;
        break;
      }
      if (tagKey.isNotEmpty &&
          itemTag == tagKey &&
          (serialKey.isEmpty ||
              itemSerial.isEmpty ||
              itemSerial == serialKey)) {
        match = item;
        break;
      }
    }
  }

  if (match == null) return job;
  return applyClientEquipmentToCalibrationJob(
    job,
    match,
    overwriteIdentity: force,
  );
}

/// Completa instrumento no job a partir do slot (opcional) e do cadastro.
CalibrationJob resolveCalibrationJobInstrument(
  CalibrationJob job, {
  OsCalibrationSlot? slot,
  SavedClient? client,
  bool forceCatalog = false,
}) {
  var next = job;
  if (slot != null) {
    next = promoteCalibrationJobInstrumentFromSlot(next, slot);
  }
  final resolvedClient =
      client ??
      ClientStore.instance.byId(next.clientId) ??
      ClientStore.instance.findMatch(
        cnpj: next.clientCnpj,
        name: next.clientName,
      );
  return fillCalibrationJobInstrumentFromClient(
    next,
    resolvedClient,
    slot: slot,
    force: forceCatalog,
  );
}

/// Atualiza certificado já gerado com a planilha/cadastro atual.
/// Mantém medições e resultados; troca TAG/N/S/local/sistema/preset/solicitante.
CalibrationJob refreshCalibrationJobFromCatalog(
  CalibrationJob job, {
  SavedClient? client,
  OsCalibrationSlot? slot,
}) {
  final resolvedClient =
      client ??
      ClientStore.instance.byId(job.clientId) ??
      ClientStore.instance.findMatch(
        cnpj: job.clientCnpj,
        name: job.clientName,
      );
  var next = resolveCalibrationJobInstrument(
    job,
    slot: slot,
    client: resolvedClient,
    forceCatalog: true,
  );
  if (resolvedClient != null) {
    if (resolvedClient.requester.trim().isNotEmpty) {
      next = next.copyWith(serviceRequester: resolvedClient.requester.trim());
    }
    if (resolvedClient.addressLine.trim().isNotEmpty) {
      next = next.copyWith(clientAddress: resolvedClient.addressLine.trim());
    }
    if (resolvedClient.name.trim().isNotEmpty &&
        next.clientName.trim().isEmpty) {
      next = next.copyWith(clientName: resolvedClient.name.trim());
    }
    if (resolvedClient.cnpj.trim().isNotEmpty) {
      next = next.copyWith(clientCnpj: resolvedClient.cnpj.trim());
    }
    if (next.clientId.trim().isEmpty && resolvedClient.id.trim().isNotEmpty) {
      next = next.copyWith(clientId: resolvedClient.id);
    }
  }
  final local = resolveCertificateInstallLocation(
    next,
    client: resolvedClient,
  );
  if (local.isNotEmpty) {
    next = next.copyWith(installLocation: local);
  } else if (!isUsefulSystemLocal(next.installLocation, site: next.site) ||
      installLocationLooksLikePresetTag(next)) {
    next = next.copyWith(installLocation: '');
  }
  next = enrichCalibrationJobFluidFromCatalog(next);
  // Catálogo altera somente a identidade do instrumento. Mantenha esta
  // barreira explícita para nenhuma evolução do refresh apagar medições,
  // conferências, padrões ou produto já preenchidos.
  final restoredFluid = next.fluid.trim().isNotEmpty
      ? next.fluid
      : (job.fluid.trim().isNotEmpty
            ? job.fluid
            : (slot?.product.trim() ?? ''));
  return next.copyWith(
    points: job.points,
    genericPoints: job.genericPoints,
    telemetryChannels: job.telemetryChannels,
    standards: job.standards,
    coriolisCoefficients: job.coriolisCoefficients,
    runCount: job.runCount,
    flowCount: job.flowCount,
    cycleCount: job.cycleCount,
    limits: job.limits,
    fluid: restoredFluid.isNotEmpty ? restoredFluid : next.fluid,
  );
}

CalibrationJob applyClientEquipmentToCalibrationJob(
  CalibrationJob job,
  ClientEquipment item, {
  bool overwriteIdentity = false,
}) {
  // Nunca apaga valor existente com string vazia do cadastro.
  // overwriteIdentity só troca quando o Excel trouxe valor real.
  String catalog(String value, String current) {
    final v = value.trim();
    final c = current.trim();
    if (overwriteIdentity) {
      if (v.isNotEmpty) return v;
      return c;
    }
    return _nonEmpty(value, current);
  }

  final itemPrinciple = item.workingPrinciple.trim().isNotEmpty
      ? item.workingPrinciple
      : item.meshWorkingPrinciple;
  final principle = catalog(itemPrinciple, job.workingPrinciple);
  final nextInstall = overwriteIdentity
      ? (item.installLocation.trim().isNotEmpty
            ? item.installLocation.trim()
            : job.installLocation)
      : _preferSystemLocal(
          preferred: item.installLocation,
          current: job.installLocation,
          site: job.site,
        );
  final beforeFluid = job.fluid.trim();
  final nextFluid = catalog(item.product, job.fluid);
  if (overwriteIdentity &&
      beforeFluid.isNotEmpty &&
      nextFluid == beforeFluid &&
      item.product.trim().isEmpty) {
    debugPrint(
      '[DATA_CHANGE] certificado ${job.number}: cadastro sem produto — '
      'preservado fluid="$beforeFluid"',
    );
  } else if (overwriteIdentity &&
      beforeFluid.isNotEmpty &&
      nextFluid != beforeFluid) {
    debugPrint(
      '[DATA_CHANGE] certificado ${job.number}: fluid '
      '"$beforeFluid" → "$nextFluid" (cadastro)',
    );
  }
  return job.copyWith(
    systemType: catalog(item.systemType, job.systemType),
    systemId: catalog(item.systemId, job.systemId),
    systemTag: catalog(item.systemTag, job.systemTag),
    assemblyKind: catalog(item.assemblyKind, job.assemblyKind),
    presetTag: catalog(item.presetTag, job.presetTag),
    presetManufacturer: catalog(
      item.presetManufacturer,
      job.presetManufacturer,
    ),
    presetModel: catalog(item.presetModel, job.presetModel),
    presetSerial: catalog(item.presetSerial, job.presetSerial),
    instrumentRole: catalog(item.instrumentRole, job.instrumentRole),
    equipmentId: item.id.trim().isNotEmpty ? item.id : job.equipmentId,
    equipmentTag: catalog(item.tag, job.equipmentTag),
    equipmentType: catalog(item.equipmentType, job.equipmentType),
    manufacturer: catalog(item.manufacturer, job.manufacturer),
    model: catalog(item.model, job.model),
    // N/S do medidor — nunca usa presetSerial como fallback.
    serialNumber: catalog(item.serialNumber, job.serialNumber),
    workingPrinciple: principle,
    fluid: nextFluid,
    installLocation: nextInstall,
  );
}

/// Recupera só `fluid` vazio a partir do slot ou do cadastro.
/// Nunca apaga fluido já preenchido. Não inventa valor sem fonte.
CalibrationJob restoreEmptyFluidFromSources(
  CalibrationJob job, {
  OsCalibrationSlot? slot,
  SavedClient? client,
}) {
  if (job.fluid.trim().isNotEmpty) return job;

  final fromSlot = slot?.product.trim() ?? '';
  if (fromSlot.isNotEmpty) {
    debugPrint(
      '[DATA_CHANGE] certificado ${job.number}: fluid vazio ← slot "$fromSlot"',
    );
    return enrichCalibrationJobFluidFromCatalog(job.copyWith(fluid: fromSlot));
  }

  final resolvedClient =
      client ??
      ClientStore.instance.byId(job.clientId) ??
      ClientStore.instance.findMatch(
        cnpj: job.clientCnpj,
        name: job.clientName,
      );
  if (resolvedClient == null) return job;

  ClientEquipment? match;
  final wantId = job.equipmentId.trim();
  final wantTag = job.equipmentTag.trim().toLowerCase();
  final wantSerial = job.serialNumber.trim().toLowerCase();
  for (final item in resolvedClient.equipment) {
    if (wantId.isNotEmpty && item.id.trim() == wantId) {
      match = item;
      break;
    }
  }
  if (match == null && wantSerial.isNotEmpty) {
    for (final item in resolvedClient.equipment) {
      if (item.serialNumber.trim().toLowerCase() == wantSerial) {
        match = item;
        break;
      }
    }
  }
  if (match == null && wantTag.isNotEmpty) {
    for (final item in resolvedClient.equipment) {
      if (item.tag.trim().toLowerCase() == wantTag) {
        match = item;
        break;
      }
    }
  }
  final fromEq = match?.product.trim() ?? '';
  if (fromEq.isEmpty) return job;
  debugPrint(
    '[DATA_CHANGE] certificado ${job.number}: fluid vazio ← cadastro "$fromEq"',
  );
  return enrichCalibrationJobFluidFromCatalog(job.copyWith(fluid: fromEq));
}

/// Cruza produto do cadastro com a biblioteca de fluidos (densidade/viscosidade).
CalibrationJob enrichCalibrationJobFluidFromCatalog(CalibrationJob job) {
  final name = job.fluid.trim().toLowerCase();
  if (name.isEmpty) return job;
  final hasDensity =
      job.fluidDensityMin.trim().isNotEmpty ||
      job.fluidDensityMax.trim().isNotEmpty;
  final hasViscosity =
      job.fluidViscosityMin.trim().isNotEmpty ||
      job.fluidViscosityMax.trim().isNotEmpty;
  if (hasDensity &&
      hasViscosity &&
      job.fluidDensityRefTemp.trim().isNotEmpty &&
      job.fluidViscosityRefTemp.trim().isNotEmpty) {
    return job;
  }
  CatalogFluid? match;
  for (final item in CalibrationCatalog.instance.fluids) {
    if (item.name.trim().toLowerCase() == name) {
      match = item;
      break;
    }
  }
  if (match == null) return job;
  return job.copyWith(
    fluidDensityMin: hasDensity ? job.fluidDensityMin : match.densityMin,
    fluidDensityMax: hasDensity ? job.fluidDensityMax : match.densityMax,
    fluidViscosityMin: hasViscosity
        ? job.fluidViscosityMin
        : match.viscosityMin,
    fluidViscosityMax: hasViscosity
        ? job.fluidViscosityMax
        : match.viscosityMax,
    fluidDensityRefTemp: job.fluidDensityRefTemp.trim().isEmpty
        ? match.densityRefTemp
        : job.fluidDensityRefTemp,
    fluidViscosityRefTemp: job.fluidViscosityRefTemp.trim().isEmpty
        ? match.viscosityRefTemp
        : job.fluidViscosityRefTemp,
    fluidReferenceTemp: job.fluidDensityRefTemp.trim().isEmpty
        ? match.densityRefTemp
        : job.fluidDensityRefTemp,
  );
}

bool clientEquipmentMatchesCalibrationKind(
  ClientEquipment item,
  CalibrationKind kind,
) {
  final role = clientInstrumentRoleFrom(item.instrumentRole);
  final type = '${item.equipmentType} ${item.systemType} ${item.assemblyKind}'
      .toLowerCase();
  final isDens =
      role == ClientInstrumentRole.densimeter || type.contains('dens');
  final isPt =
      role == ClientInstrumentRole.pt100 ||
      role == ClientInstrumentRole.mesh ||
      type.contains('pt100') ||
      type.contains('pt 100') ||
      type.contains('termorresist') ||
      type.contains('sensor de temperatura') ||
      item.workingPrinciple.toLowerCase().contains('termorresist');
  final isPressure =
      type.contains('manom') || type.contains('press') || type.contains('psv');
  final isTelemetry = type.contains('telemetr');
  final isMeter =
      role == ClientInstrumentRole.meter ||
      type.contains('medidor') ||
      type.contains('vaz') ||
      type.contains('coriolis') ||
      type.contains('ultrass') ||
      type.contains('turbina');

  switch (kind) {
    case CalibrationKind.volumetric:
    case CalibrationKind.volumetricInverted:
      // Só medidor / vazão — não “rouba” PT100, densímetro nem pressão.
      if (isDens || isPt || isPressure || isTelemetry) return false;
      return isMeter ||
          item.presetTag.trim().isNotEmpty ||
          item.presetSerial.trim().isNotEmpty ||
          type.contains('skid') ||
          type.contains('preset') ||
          // Instrumento genérico com TAG+N/S e papel de medidor (padrão).
          (role == ClientInstrumentRole.meter &&
              item.tag.trim().isNotEmpty &&
              item.serialNumber.trim().isNotEmpty);
    case CalibrationKind.telemetry:
      return isTelemetry;
    case CalibrationKind.temperature:
      // Somente sensor de temperatura / PT100 (não transmissor de vazão).
      return isPt;
    case CalibrationKind.temperatureMesh:
      return role == ClientInstrumentRole.mesh ||
          (role == ClientInstrumentRole.pt100 &&
              item.meshTag.trim().isNotEmpty);
    case CalibrationKind.density:
      return isDens;
    case CalibrationKind.pressure:
      return isPressure;
    case CalibrationKind.conductivity:
      return isMeter || role == ClientInstrumentRole.transmitter;
  }
}

/// Chave de uso na OS: medidor volumétrico com vários produtos tem um
/// certificado por produto, então o mesmo id pode aparecer uma vez por produto.
String calibrationUseKey(String kind, String equipmentId, String product) {
  final id = equipmentId.trim();
  if (!_claimsPerProduct(kind)) return id;
  final p = product.trim().toLowerCase();
  return p.isEmpty ? id : '$id|$p';
}

/// Medidor com vários produtos vira uma linha por produto (mesmo id).
List<ClientEquipment> expandClientEquipmentPerProduct(
  List<ClientEquipment> items,
) {
  return [
    for (final item in items)
      ...() {
        final products = splitClientProducts(item.product);
        if (products.length < 2) return [item];
        return [for (final p in products) item.copyWith(product: p)];
      }(),
  ];
}

List<ClientEquipment> clientEquipmentForCalibration({
  required List<ClientEquipment> equipment,
  required CalibrationKind kind,
  required Set<String> usedIds,
  String installLocation = '',
  String systemType = '',

  /// Medidor volumétrico com N produtos entra N vezes; [usedIds] usa
  /// [calibrationUseKey].
  bool perProduct = false,
}) {
  final expand =
      perProduct &&
      (kind == CalibrationKind.volumetric ||
          kind == CalibrationKind.volumetricInverted);
  final source = expand ? expandClientEquipmentPerProduct(equipment) : equipment;
  final multiProductIds = <String>{
    if (expand)
      for (final item in equipment)
        if (splitClientProducts(item.product).length > 1) item.id,
  };
  bool used(ClientEquipment item) {
    if (usedIds.contains(item.id)) return true;
    if (!expand) return false;
    if (multiProductIds.contains(item.id)) {
      return usedIds.contains(
        calibrationUseKey(kind.name, item.id, item.product),
      );
    }
    return usedIds.any((key) => key.startsWith('${item.id}|'));
  }
  final locKey = installLocation.trim().toLowerCase();
  final sysKey = systemType.trim().toLowerCase();
  bool matchesPlace(ClientEquipment item) {
    final itemLoc = item.installLocation.trim().toLowerCase();
    final itemSys = item.systemType.trim().toLowerCase();
    final locOk =
        locKey.isEmpty ||
        itemLoc.isEmpty ||
        itemLoc == locKey ||
        itemLoc.contains(locKey) ||
        locKey.contains(itemLoc);
    final sysOk =
        sysKey.isEmpty ||
        itemSys.isEmpty ||
        itemSys == sysKey ||
        itemSys.contains(sysKey) ||
        sysKey.contains(itemSys);
    return locOk && sysOk;
  }

  final strict = <ClientEquipment>[];
  final relaxed = <ClientEquipment>[];
  for (final item in source) {
    if (used(item)) continue;
    if (!clientEquipmentMatchesCalibrationKind(item, kind)) continue;
    // Prioriza quem tem tag ou N/S (inclui N/S do preset).
    final hasIdentity =
        item.tag.trim().isNotEmpty ||
        item.serialNumber.trim().isNotEmpty ||
        item.presetTag.trim().isNotEmpty ||
        item.presetSerial.trim().isNotEmpty;
    if (!hasIdentity &&
        item.manufacturer.trim().isEmpty &&
        item.model.trim().isEmpty) {
      continue;
    }
    if (matchesPlace(item)) {
      strict.add(item);
    } else {
      relaxed.add(item);
    }
  }
  int rank(ClientEquipment item) {
    var score = 0;
    if (item.serialNumber.trim().isNotEmpty) score += 4;
    if (item.presetSerial.trim().isNotEmpty) score += 3;
    if (item.tag.trim().isNotEmpty) score += 2;
    if (item.presetTag.trim().isNotEmpty) score += 1;
    return score;
  }

  strict.sort((a, b) => rank(b).compareTo(rank(a)));
  relaxed.sort((a, b) => rank(b).compareTo(rank(a)));
  // Se o local/tipo da OS filtrar demais, ainda assim oferece os instrumentos.
  return [...strict, ...relaxed];
}

OsCalibrationSlot mergeSlotWithEquipment({
  required OsCalibrationSlot slot,
  required ClientEquipment equipment,
}) {
  final base = OsCalibrationSlot.fromEquipment(
    id: slot.id,
    kind: slot.kind,
    certificateNumber: slot.certificateNumber,
    equipment: equipment,
    dataCheck: slot.dataCheck,
    divergentNote: slot.divergentNote,
    jobId: slot.jobId,
    catalogStatus: slot.catalogStatus,
    catalogSubmittedAt: slot.catalogSubmittedAt,
    catalogSubmittedBy: slot.catalogSubmittedBy,
    catalogReviewNote: slot.catalogReviewNote,
    catalogReviewedAt: slot.catalogReviewedAt,
    catalogReviewedBy: slot.catalogReviewedBy,
  );
  // Excel vazio NÃO apaga o que já está no slot.
  String keep(String fromExcel, String current) =>
      fromExcel.trim().isNotEmpty ? fromExcel.trim() : current;
  final serial = base.serialNumber.trim().isNotEmpty
      ? base.serialNumber
      : slot.serialNumber;
  // Medidor com vários produtos: cada slot é a calibração de um deles.
  final product = splitClientProducts(base.product).length > 1
      ? slot.product.trim()
      : keep(base.product, slot.product);
  return base.copyWith(
    labelDate: slot.labelDate,
    serialNumber: serial,
    product: product,
    equipmentTag: keep(base.equipmentTag, slot.equipmentTag),
    manufacturer: keep(base.manufacturer, slot.manufacturer),
    model: keep(base.model, slot.model),
    installLocation: keep(base.installLocation, slot.installLocation),
    presetTag: keep(base.presetTag, slot.presetTag),
    presetSerial: keep(base.presetSerial, slot.presetSerial),
    presetManufacturer: keep(base.presetManufacturer, slot.presetManufacturer),
    presetModel: keep(base.presetModel, slot.presetModel),
  );
}

/// Escolhe o equipamento do Excel para o slot (TAG / N/S / preset).
/// Com [preferRematch] ignora vínculo velho por id quando a TAG aponta
/// para outra linha do cadastro (causa clássica de produto errado).
ClientEquipment? matchClientEquipmentForSlot({
  required OsCalibrationSlot slot,
  required List<ClientEquipment> pool,
  Map<String, ClientEquipment> equipmentById = const {},
  bool preferRematch = false,
}) {
  final tagKey = slot.equipmentTag.trim().toLowerCase();
  final presetKey = slot.presetTag.trim().toLowerCase();
  final serialKey = slot.serialNumber.trim().toLowerCase();
  final productKey = slot.product.trim().toLowerCase();
  var bySerial = <ClientEquipment>[];
  var byTag = <ClientEquipment>[];
  var byPreset = <ClientEquipment>[];
  for (final item in pool) {
    final t = item.tag.trim().toLowerCase();
    final p = item.presetTag.trim().toLowerCase();
    final s = item.serialNumber.trim().toLowerCase();
    if (serialKey.isNotEmpty && s == serialKey) bySerial.add(item);
    if (tagKey.isNotEmpty && (t == tagKey || p == tagKey)) byTag.add(item);
    if (presetKey.isNotEmpty && (p == presetKey || t == presetKey)) {
      byPreset.add(item);
    }
  }
  // Mesmo medidor em várias linhas do Excel (uma por produto): o produto
  // do slot escolhe a linha.
  List<ClientEquipment> byProduct(List<ClientEquipment> hits) {
    if (hits.length < 2 || productKey.isEmpty) return hits;
    final same = [
      for (final item in hits)
        if (item.product.trim().toLowerCase() == productKey) item,
    ];
    return same.isEmpty ? hits : same;
  }

  bySerial = byProduct(bySerial);
  byTag = byProduct(byTag);
  byPreset = byProduct(byPreset);

  if (preferRematch) {
    // No pull forçado a TAG manda: o N/S do slot pode ainda ser o do vínculo
    // errado (contaminado). Trocar pela linha certa do Excel.
    if (byTag.length == 1) return byTag.first;
    if (bySerial.length == 1) {
      final hit = bySerial.first;
      final hitTag = hit.tag.trim().toLowerCase();
      if (tagKey.isEmpty || hitTag.isEmpty || hitTag == tagKey) return hit;
    }
    if (byPreset.length == 1 && tagKey.isEmpty && serialKey.isEmpty) {
      return byPreset.first;
    }
  } else {
    if (bySerial.length == 1) return bySerial.first;
    if (byTag.length == 1) return byTag.first;
    if (byPreset.length == 1 && tagKey.isEmpty && serialKey.isEmpty) {
      return byPreset.first;
    }
  }

  final linked = equipmentById[slot.equipmentId.trim()];
  if (linked == null) return null;
  if (!preferRematch) return linked;

  // Pull forçado: id antigo só vale se a TAG/N/S batem com a linha atual.
  final linkedTag = linked.tag.trim().toLowerCase();
  final linkedSerial = linked.serialNumber.trim().toLowerCase();
  if (tagKey.isNotEmpty && linkedTag.isNotEmpty && tagKey != linkedTag) {
    return null;
  }
  if (serialKey.isNotEmpty &&
      linkedSerial.isNotEmpty &&
      serialKey != linkedSerial &&
      serialKey != linked.presetSerial.trim().toLowerCase()) {
    return null;
  }
  return linked;
}

bool _claimsPerProduct(String kind) {
  final k = calibrationKindFrom(kind);
  return k == CalibrationKind.volumetric ||
      k == CalibrationKind.volumetricInverted;
}

/// Instrumento já usado na OS. O medidor volumétrico é certificado uma vez
/// por produto (mesmo N/S em várias linhas do Excel); sensores, uma vez só.
/// O tipo entra na chave: PT100 e densímetro podem ter o mesmo texto de N/S.
String _instrumentClaimKey(String kind, String serial, String product) {
  final k = calibrationKindFrom(kind).name;
  final s = serial.trim().toLowerCase();
  final p = _claimsPerProduct(kind) ? product.trim().toLowerCase() : '';
  return '$k|$s|$p';
}

bool _instrumentClaimed(
  Set<String> claims,
  String kind,
  String serial,
  String product,
) {
  if (serial.trim().isEmpty) return false;
  final any = _instrumentClaimKey(kind, serial, '');
  if (claims.contains(any)) return true;
  if (!_claimsPerProduct(kind)) return false;
  if (product.trim().isEmpty) {
    return claims.any((key) => key.startsWith(any));
  }
  return claims.contains(_instrumentClaimKey(kind, serial, product));
}

CalibrationJob? _jobForOsSlot(
  OsCalibrationSlot slot, {
  required List<CalibrationJob> jobs,
  required String osId,
  required String osNumber,
}) {
  if (slot.jobId.trim().isNotEmpty) {
    for (final job in jobs) {
      if (job.id != slot.jobId) continue;
      if (calibrationJobBelongsToOs(
        job,
        osId: osId,
        osNumber: osNumber,
        slotId: slot.id,
      )) {
        return job;
      }
      break;
    }
  }
  final number = slot.certificateNumber.trim().toLowerCase();
  if (number.isEmpty) return null;
  for (final job in jobs) {
    if (job.number.trim().toLowerCase() != number) continue;
    if (!calibrationJobBelongsToOs(
      job,
      osId: osId,
      osNumber: osNumber,
      slotId: slot.id,
    )) {
      continue;
    }
    return job;
  }
  return null;
}

/// Slot órfão (sem job) com N/S já usado por outro certificado → zera cadastro.
List<OsCalibrationSlot> clearDuplicateOrphanSlotSerials(
  List<OsCalibrationSlot> slots, {
  List<CalibrationJob> jobs = const [],
  String osId = '',
  String osNumber = '',
}) {
  CalibrationJob? jobFor(OsCalibrationSlot slot) =>
      _jobForOsSlot(slot, jobs: jobs, osId: osId, osNumber: osNumber);

  final claimed = <String>{};
  // Primeiro: N/S de slots que têm calibração.
  for (final slot in slots) {
    final job = jobFor(slot);
    if (job == null) continue;
    final serial = _meterSerialForDisplay(slot, job);
    if (serial.trim().isEmpty) continue;
    final product = slot.product.trim().isNotEmpty ? slot.product : job.fluid;
    claimed.add(_instrumentClaimKey(slot.kind, serial, product));
  }

  return [
    for (final slot in slots)
      () {
        final job = jobFor(slot);
        if (job != null) return slot;
        final serial = slot.serialNumber;
        if (serial.trim().isEmpty ||
            !_instrumentClaimed(claimed, slot.kind, serial, slot.product)) {
          if (serial.trim().isNotEmpty) {
            claimed.add(_instrumentClaimKey(slot.kind, serial, slot.product));
          }
          return slot;
        }
        // Duplicata órfã do N/S de um certificado real.
        return slot.copyWith(
          equipmentId: '',
          equipmentTag: '',
          serialNumber: '',
          product: '',
          presetTag: '',
          presetSerial: '',
          manufacturer: '',
          model: '',
        );
      }(),
  ];
}

List<OsCalibrationSlot> refreshOsCalibrationSlots({
  required List<OsCalibrationSlot> slots,
  required SavedClient? client,
  String installLocation = '',
  String systemType = '',
  List<CalibrationJob> jobs = const [],
  String osId = '',
  String osNumber = '',
  bool forceCatalog = false,
  bool onlyFillEmptySerial = false,
}) {
  var working = slots;
  // No pull explícito o slot é a âncora do vínculo com o Excel. Copiar antes
  // a identidade antiga do job faria o cadastro "voltar" para o instrumento
  // errado e escolher novamente seu equipmentId obsoleto.
  // Puxar N/S vazio também não copia o job: senão o certificado vizinho entra no slot.
  if (!forceCatalog && !onlyFillEmptySerial && jobs.isNotEmpty) {
    working = enrichOsSlotsFromCalibrationJobs(
      slots: working,
      jobs: jobs,
      osId: osId,
      osNumber: osNumber,
    );
  }
  // N/S repetido em slot sem calibração própria (ex.: 0004 e 0006) → limpa.
  if (!forceCatalog) {
    working = clearDuplicateOrphanSlotSerials(
      working,
      jobs: jobs,
      osId: osId,
      osNumber: osNumber,
    );
  }
  if (client == null || working.isEmpty) return working;
  final equipmentById = {for (final item in client.equipment) item.id: item};
  final catalogSerials = <String>{
    for (final item in client.equipment) ...[
      if (item.serialNumber.trim().isNotEmpty)
        item.serialNumber.trim().toLowerCase(),
      if (item.presetSerial.trim().isNotEmpty)
        item.presetSerial.trim().toLowerCase(),
    ],
  };
  // Puxar N/S: slot sem certificado iniciado nem conferência, com N/S que
  // não existe no cadastro deste cliente, é planejamento velho — preenche de novo.
  bool staleIdentity(OsCalibrationSlot slot) {
    if (!onlyFillEmptySerial) return false;
    final serial = slot.serialNumber.trim().toLowerCase();
    if (serial.isEmpty || catalogSerials.contains(serial)) return false;
    if (slot.jobId.trim().isNotEmpty ||
        slot.catalogStatus.trim().isNotEmpty ||
        slot.dataCheck.trim().isNotEmpty) {
      return false;
    }
    return _jobForOsSlot(slot, jobs: jobs, osId: osId, osNumber: osNumber) ==
        null;
  }

  working = [
    for (final slot in working)
      if (staleIdentity(slot))
        slot.copyWith(
          equipmentId: '',
          equipmentTag: '',
          serialNumber: '',
          product: '',
          presetTag: '',
          presetSerial: '',
          manufacturer: '',
          model: '',
        )
      else
        slot,
  ];
  // Reserva equipamento já ligado (por id ou N/S) para não repetir medidor.
  final usedIds = <String>{
    for (final slot in working)
      if (slot.equipmentId.isNotEmpty &&
          equipmentById.containsKey(slot.equipmentId))
        calibrationUseKey(slot.kind, slot.equipmentId, slot.product),
  };
  final usedSerials = <String>{
    for (final slot in working)
      if (slot.serialNumber.trim().isNotEmpty)
        _instrumentClaimKey(slot.kind, slot.serialNumber, slot.product),
  };
  final next = <OsCalibrationSlot>[];
  void take(OsCalibrationSlot slot, ClientEquipment equipment) {
    final merged = mergeSlotWithEquipment(slot: slot, equipment: equipment);
    usedIds.add(calibrationUseKey(slot.kind, equipment.id, merged.product));
    if (equipment.serialNumber.trim().isNotEmpty) {
      usedSerials.add(
        _instrumentClaimKey(slot.kind, equipment.serialNumber, merged.product),
      );
    }
    next.add(merged);
  }

  for (final slot in working) {
    if (onlyFillEmptySerial && slot.serialNumber.trim().isNotEmpty) {
      if (slot.equipmentId.isNotEmpty) {
        usedIds.add(
          calibrationUseKey(slot.kind, slot.equipmentId, slot.product),
        );
      }
      next.add(slot);
      continue;
    }
    if (!forceCatalog && slot.locksCatalogRefresh) {
      // Confirmado: não remonta o vínculo, mas aplica a linha já ligada
      // (produto/N/S do Excel atualizados na mesma equipmentId).
      final linked = equipmentById[slot.equipmentId.trim()];
      if (linked != null) {
        take(slot, linked);
      } else {
        next.add(slot);
      }
      continue;
    }
    final kind = calibrationKindFrom(slot.kind);
    // No pull forçado, o pool inclui ids já usados para permitir remontar
    // o vínculo certo por TAG (libera o equipmentId errado).
    final pool = [
      for (final item in clientEquipmentForCalibration(
        equipment: client.equipment,
        kind: kind,
        usedIds: forceCatalog ? <String>{} : usedIds,
        installLocation: installLocation,
        systemType: systemType,
        perProduct: true,
      ))
        if (forceCatalog ||
            !_instrumentClaimed(
              usedSerials,
              slot.kind,
              item.serialNumber,
              item.product,
            ))
          item,
    ];
    var equipment = matchClientEquipmentForSlot(
      slot: slot,
      pool: pool,
      equipmentById: equipmentById,
      preferRematch: forceCatalog,
    );
    if (equipment == null &&
        !forceCatalog &&
        slot.equipmentId.isNotEmpty &&
        equipmentById.containsKey(slot.equipmentId)) {
      equipment = equipmentById[slot.equipmentId];
    }
    if (equipment == null && forceCatalog) {
      // Ainda sem match: se o id existe, aplica a linha atual do Excel
      // (produto/TAG atualizados na mesma linha).
      final linked = equipmentById[slot.equipmentId.trim()];
      if (linked != null) equipment = linked;
    }
    if (equipment != null) {
      take(slot, equipment);
      continue;
    }
    final needsFill =
        slot.needsCadastro ||
        slot.serialNumber.trim().isEmpty ||
        slot.equipmentId.isEmpty ||
        !equipmentById.containsKey(slot.equipmentId);
    if (needsFill &&
        pool.isNotEmpty &&
        slot.equipmentTag.trim().isEmpty &&
        slot.serialNumber.trim().isEmpty &&
        slot.presetTag.trim().isEmpty) {
      // Preenchimento inicial da OS: próximo equipamento livre.
      String keyOf(ClientEquipment item) =>
          calibrationUseKey(slot.kind, item.id, item.product);
      equipment = pool.firstWhere(
        (item) => !usedIds.contains(keyOf(item)),
        orElse: () => pool.first,
      );
      if (!usedIds.contains(keyOf(equipment))) {
        take(slot, equipment);
        continue;
      }
    }
    next.add(slot);
  }
  return next;
}

/// Copia produto/TAG/N/S do slot (edição na OS) para o certificado ligado.
CalibrationJob applyOsSlotInstrumentToCalibrationJob(
  CalibrationJob job,
  OsCalibrationSlot slot,
) {
  var next = job.copyWith(
    equipmentId: slot.equipmentId.trim().isNotEmpty
        ? slot.equipmentId.trim()
        : job.equipmentId,
    equipmentTag: slot.equipmentTag.trim().isNotEmpty
        ? slot.equipmentTag.trim()
        : job.equipmentTag,
    equipmentType: slot.equipmentType.trim().isNotEmpty
        ? slot.equipmentType.trim()
        : job.equipmentType,
    manufacturer: slot.manufacturer.trim().isNotEmpty
        ? slot.manufacturer.trim()
        : job.manufacturer,
    model: slot.model.trim().isNotEmpty ? slot.model.trim() : job.model,
    serialNumber: slot.serialNumber.trim().isNotEmpty
        ? slot.serialNumber.trim()
        : job.serialNumber,
    workingPrinciple: slot.workingPrinciple.trim().isNotEmpty
        ? slot.workingPrinciple.trim()
        : job.workingPrinciple,
    installLocation: slot.installLocation.trim().isNotEmpty
        ? slot.installLocation.trim()
        : job.installLocation,
    systemType: slot.systemType.trim().isNotEmpty
        ? slot.systemType.trim()
        : job.systemType,
    systemId: slot.systemId.trim().isNotEmpty
        ? slot.systemId.trim()
        : job.systemId,
    systemTag: slot.systemTag.trim().isNotEmpty
        ? slot.systemTag.trim()
        : job.systemTag,
    assemblyKind: slot.assemblyKind.trim().isNotEmpty
        ? slot.assemblyKind.trim()
        : job.assemblyKind,
    presetTag: slot.presetTag.trim().isNotEmpty
        ? slot.presetTag.trim()
        : job.presetTag,
    presetManufacturer: slot.presetManufacturer.trim().isNotEmpty
        ? slot.presetManufacturer.trim()
        : job.presetManufacturer,
    presetModel: slot.presetModel.trim().isNotEmpty
        ? slot.presetModel.trim()
        : job.presetModel,
    presetSerial: slot.presetSerial.trim().isNotEmpty
        ? slot.presetSerial.trim()
        : job.presetSerial,
    instrumentRole: slot.instrumentRole.trim().isNotEmpty
        ? slot.instrumentRole.trim()
        : job.instrumentRole,
    fluid: slot.product.trim().isNotEmpty ? slot.product.trim() : job.fluid,
    calibrationSlotId: slot.id.trim().isNotEmpty
        ? slot.id
        : job.calibrationSlotId,
  );
  return enrichCalibrationJobFluidFromCatalog(next);
}

/// Copia TAG/N/S (e afins) do certificado preenchido para o slot da OS.
OsCalibrationSlot applyCalibrationJobToOsSlot(
  OsCalibrationSlot slot,
  CalibrationJob job,
) {
  // Certificado preenchido manda no instrumento (evita slot contaminado
  // sobrescrever TAG/N/S certos do job). Produto do slot (lápis) prevalece.
  String pick(String slotVal, String jobVal) {
    if (jobVal.trim().isNotEmpty) return jobVal.trim();
    return slotVal;
  }

  var next = slot.copyWith(
    jobId: job.id,
    // Se o save renumerou (nº já existia noutra OS), o slot precisa acompanhar
    // — senão a lista mostra 0060 e a tela abre 0146.
    certificateNumber: job.number.trim().isNotEmpty
        ? job.number.trim()
        : slot.certificateNumber,
    equipmentId: pick(slot.equipmentId, job.equipmentId),
    equipmentTag: pick(slot.equipmentTag, job.equipmentTag),
    equipmentType: pick(slot.equipmentType, job.equipmentType),
    manufacturer: pick(slot.manufacturer, job.manufacturer),
    model: pick(slot.model, job.model),
    serialNumber: pick(slot.serialNumber, job.serialNumber),
    workingPrinciple: pick(slot.workingPrinciple, job.workingPrinciple),
    installLocation: _preferSystemLocal(
      preferred: job.installLocation,
      current: slot.installLocation,
      site: '',
    ),
    systemType: pick(slot.systemType, job.systemType),
    systemId: pick(slot.systemId, job.systemId),
    systemTag: pick(slot.systemTag, job.systemTag),
    assemblyKind: pick(slot.assemblyKind, job.assemblyKind),
    presetTag: pick(slot.presetTag, job.presetTag),
    presetManufacturer: pick(slot.presetManufacturer, job.presetManufacturer),
    presetModel: pick(slot.presetModel, job.presetModel),
    presetSerial: pick(slot.presetSerial, job.presetSerial),
    instrumentRole: pick(slot.instrumentRole, job.instrumentRole),
    // Produto do slot (lápis/cadastro na OS) não é sobrescrito pelo fluido antigo do job.
    product: slot.product.trim().isNotEmpty
        ? slot.product.trim()
        : job.fluid.trim(),
  );
  switch (job.kind) {
    case CalibrationKind.density:
      next = next.copyWith(
        densimeterTag: pick(slot.densimeterTag, job.equipmentTag),
        densimeterSerial: pick(slot.densimeterSerial, job.serialNumber),
        densimeterManufacturer: pick(
          slot.densimeterManufacturer,
          job.manufacturer,
        ),
        densimeterModel: pick(slot.densimeterModel, job.model),
        densimeterWorkingPrinciple: pick(
          slot.densimeterWorkingPrinciple,
          job.workingPrinciple,
        ),
      );
      break;
    case CalibrationKind.temperature:
      next = next.copyWith(
        pt100Tag: pick(slot.pt100Tag, job.equipmentTag),
        pt100Serial: pick(slot.pt100Serial, job.serialNumber),
        pt100Manufacturer: pick(slot.pt100Manufacturer, job.manufacturer),
        pt100Model: pick(slot.pt100Model, job.model),
        pt100WorkingPrinciple: pick(
          slot.pt100WorkingPrinciple,
          job.workingPrinciple,
        ),
      );
      break;
    case CalibrationKind.temperatureMesh:
      next = next.copyWith(
        meshTag: pick(slot.meshTag, job.equipmentTag),
        meshSerialNumber: pick(slot.meshSerialNumber, job.serialNumber),
        meshManufacturer: pick(slot.meshManufacturer, job.manufacturer),
        meshModel: pick(slot.meshModel, job.model),
        meshWorkingPrinciple: pick(
          slot.meshWorkingPrinciple,
          job.workingPrinciple,
        ),
        meshEquipmentType: pick(slot.meshEquipmentType, job.equipmentType),
      );
      break;
    case CalibrationKind.pressure:
      next = next.copyWith(
        pressureTag: pick(slot.pressureTag, job.equipmentTag),
        pressureSerial: pick(slot.pressureSerial, job.serialNumber),
        pressureManufacturer: pick(slot.pressureManufacturer, job.manufacturer),
        pressureModel: pick(slot.pressureModel, job.model),
        pressureWorkingPrinciple: pick(
          slot.pressureWorkingPrinciple,
          job.workingPrinciple,
        ),
      );
      break;
    case CalibrationKind.telemetry:
      next = next.copyWith(
        telemetryTag: pick(slot.telemetryTag, job.equipmentTag),
        telemetrySerial: pick(slot.telemetrySerial, job.serialNumber),
        telemetryManufacturer: pick(
          slot.telemetryManufacturer,
          job.manufacturer,
        ),
        telemetryModel: pick(slot.telemetryModel, job.model),
        telemetryWorkingPrinciple: pick(
          slot.telemetryWorkingPrinciple,
          job.workingPrinciple,
        ),
      );
      break;
    case CalibrationKind.volumetric:
    case CalibrationKind.volumetricInverted:
    case CalibrationKind.conductivity:
      break;
  }
  return next;
}

/// Job pertence a esta OS? Só rejeita conflito explícito de OS
/// (Phoenix ≠ Rio Verde). Não exige bater slotId — slots podem ser
/// recriados e o vínculo por nº/jobId continua válido.
bool calibrationJobBelongsToOs(
  CalibrationJob job, {
  required String osId,
  required String osNumber,
  String slotId = '',
  Set<String>? allowedSlotIds,
}) {
  final wantId = osId.trim();
  final wantNum = osNumber.trim().toLowerCase();
  final jOsId = job.osId.trim();
  final jOsNum = job.osNumber.trim().toLowerCase();
  final jSlot = job.calibrationSlotId.trim();

  if (wantId.isNotEmpty && jOsId.isNotEmpty && jOsId != wantId) {
    return false;
  }
  if (wantNum.isNotEmpty && jOsNum.isNotEmpty && jOsNum != wantNum) {
    return false;
  }

  // Listagem da OS: jobs sem OS só entram se estiverem ligados a um slot
  // desta OS. Aceitar job totalmente órfão por número contaminava outra OS.
  if (allowedSlotIds != null && allowedSlotIds.isNotEmpty) {
    if (jOsId.isNotEmpty || jOsNum.isNotEmpty) return true;
    if (jSlot.isNotEmpty) return allowedSlotIds.contains(jSlot);
    return false;
  }

  if ((wantId.isNotEmpty || wantNum.isNotEmpty) &&
      jOsId.isEmpty &&
      jOsNum.isEmpty) {
    return slotId.trim().isNotEmpty && jSlot == slotId.trim();
  }
  return true;
}

List<CalibrationJob> calibrationJobsForOs(
  Iterable<CalibrationJob> jobs, {
  required String osId,
  required String osNumber,
  Iterable<String> slotIds = const [],
}) {
  final allowed = {
    for (final id in slotIds)
      if (id.trim().isNotEmpty) id.trim(),
  };
  return [
    for (final job in jobs)
      if (calibrationJobBelongsToOs(
        job,
        osId: osId,
        osNumber: osNumber,
        allowedSlotIds: allowed.isEmpty ? null : allowed,
      ))
        job,
  ];
}

List<OsCalibrationSlot> enrichOsSlotsFromCalibrationJobs({
  required List<OsCalibrationSlot> slots,
  required List<CalibrationJob> jobs,
  String osId = '',
  String osNumber = '',
}) {
  if (slots.isEmpty || jobs.isEmpty) return slots;
  final scoped = (osId.trim().isNotEmpty || osNumber.trim().isNotEmpty)
      ? calibrationJobsForOs(
          jobs,
          osId: osId,
          osNumber: osNumber,
          slotIds: [for (final s in slots) s.id],
        )
      : jobs.toList();

  CalibrationJob? findJob(OsCalibrationSlot slot) {
    if (scoped.isEmpty) return null;
    if (slot.jobId.trim().isNotEmpty) {
      for (final job in scoped) {
        if (job.id == slot.jobId) return job;
      }
    }
    if (slot.id.trim().isNotEmpty) {
      for (final job in scoped) {
        if (job.calibrationSlotId.trim() == slot.id) return job;
      }
    }
    final number = slot.certificateNumber.trim().toLowerCase();
    if (number.isEmpty) return null;
    // Prefere job da mesma OS; evita órfão genérico se houver um amarrado.
    CalibrationJob? orphan;
    for (final job in scoped) {
      if (job.number.trim().toLowerCase() != number) continue;
      if (job.osId.trim().isNotEmpty || job.osNumber.trim().isNotEmpty) {
        return job;
      }
      orphan ??= job;
    }
    return orphan;
  }

  return [
    for (final slot in slots)
      () {
        final job = findJob(slot);
        if (job != null) return applyCalibrationJobToOsSlot(slot, job);
        // Só solta jobId se o certificado for claramente de outra OS.
        if (slot.jobId.trim().isNotEmpty &&
            (osId.trim().isNotEmpty || osNumber.trim().isNotEmpty)) {
          CalibrationJob? linked;
          for (final j in jobs) {
            if (j.id == slot.jobId) {
              linked = j;
              break;
            }
          }
          if (linked != null &&
              !calibrationJobBelongsToOs(
                linked,
                osId: osId,
                osNumber: osNumber,
              )) {
            return slot.copyWith(
              jobId: '',
              equipmentTag: slot.equipmentTag == linked.equipmentTag
                  ? ''
                  : slot.equipmentTag,
              serialNumber: slot.serialNumber == linked.serialNumber
                  ? ''
                  : slot.serialNumber,
              presetTag: slot.presetTag == linked.presetTag
                  ? ''
                  : slot.presetTag,
              product: slot.product == linked.fluid ? '' : slot.product,
            );
          }
        }
        return slot;
      }(),
  ];
}

/// Tem TAG/N/S no slot ou no certificado já preenchido (para adesivo).
bool calibrationSlotReadyForLabel(
  OsCalibrationSlot slot, {
  CalibrationJob? job,
}) {
  if (!slot.needsCadastro) return true;
  if (job == null) return false;
  return job.equipmentTag.trim().isNotEmpty ||
      job.serialNumber.trim().isNotEmpty ||
      job.equipmentId.trim().isNotEmpty;
}

/// Cadastro pendente significa que TAG/N/S não existem nem no slot nem no
/// certificado ligado. O estado do certificado não o devolve à aba pendente.
bool calibrationSlotNeedsCadastro(
  OsCalibrationSlot slot, {
  CalibrationJob? job,
}) {
  return !calibrationSlotReadyForLabel(slot, job: job);
}

/// Slot planejado na OS sem calibração iniciada (sobressalente).
bool calibrationSlotIsOrphanWithoutJob(
  OsCalibrationSlot slot, {
  CalibrationJob? job,
}) {
  return job == null && slot.needsCadastro;
}

/// N/S do medidor para lista/PDF — nunca usa o N/S do preset como fallback.
String _meterSerialForDisplay(OsCalibrationSlot slot, CalibrationJob? job) {
  final presetKeys = <String>{
    if (slot.presetSerial.trim().isNotEmpty)
      slot.presetSerial.trim().toLowerCase(),
    if ((job?.presetSerial ?? '').trim().isNotEmpty)
      job!.presetSerial.trim().toLowerCase(),
  };
  final slotSerial = slot.serialNumber.trim();
  final jobSerial = (job?.serialNumber ?? '').trim();
  if (jobSerial.isNotEmpty && !presetKeys.contains(jobSerial.toLowerCase())) {
    return jobSerial;
  }
  if (slotSerial.isNotEmpty && !presetKeys.contains(slotSerial.toLowerCase())) {
    return slotSerial;
  }
  if (slotSerial.isNotEmpty) return slotSerial;
  return '';
}

/// Chave do medidor de um certificado: dois certificados com a mesma chave
/// na mesma OS são o mesmo instrumento (um deles está errado).
/// Sensores de temperatura ficam de fora: o N/S do PT100 é o do lote e se
/// repete em sensores diferentes.
String calibrationMeterKey(CalibrationJob job) {
  if (job.kind == CalibrationKind.temperature ||
      job.kind == CalibrationKind.temperatureMesh) {
    return '';
  }
  String norm(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  final serial = norm(job.serialNumber);
  if (serial.isEmpty) return '';
  return '${job.kind.name}|$serial|${norm(job.fluid)}';
}

/// Para cada slot, os outros certificados da OS com o mesmo medidor.
Map<String, List<String>> calibrationSlotsSharingMeter(
  List<OsCalibrationSlot> slots,
  CalibrationJob? Function(OsCalibrationSlot slot) jobOf,
) {
  final bySlot = <String, String>{};
  final byKey = <String, List<OsCalibrationSlot>>{};
  for (final slot in slots) {
    final job = jobOf(slot);
    if (job == null) continue;
    final key = calibrationMeterKey(
      calibrationJobForCertificatePrint(job, slot: slot),
    );
    if (key.isEmpty) continue;
    bySlot[slot.id] = key;
    byKey.putIfAbsent(key, () => []).add(slot);
  }
  return {
    for (final entry in bySlot.entries)
      if (byKey[entry.value]!.length > 1)
        entry.key: [
          for (final other in byKey[entry.value]!)
            if (other.id != entry.key) other.certificateNumber,
        ],
  };
}

/// Campos em que a OS indica outro instrumento que o certificado.
/// Cada item já vem como texto para o aviso (ex.: `TAG FT 1`).
List<String> calibrationSlotJobMismatch(
  OsCalibrationSlot slot,
  CalibrationJob job,
) {
  String norm(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  final out = <String>[];
  void compare(String label, String jobValue, String slotValue) {
    final a = norm(jobValue);
    final b = norm(slotValue);
    if (a.isEmpty || b.isEmpty || a == b) return;
    out.add('$label ${slotValue.trim()}');
  }

  compare('TAG', job.equipmentTag, slot.equipmentTag);
  compare('N/S', job.serialNumber, slot.serialNumber);
  compare('Preset', job.presetTag, slot.presetTag);
  return out;
}

String osCalibrationSlotDetailLine(
  OsCalibrationSlot slot, {
  CalibrationJob? job,
  bool includeKind = false,
}) {
  final ready = calibrationSlotReadyForLabel(slot, job: job);
  final orphan = calibrationSlotIsOrphanWithoutJob(slot, job: job);
  final tag = (job?.equipmentTag.trim().isNotEmpty ?? false)
      ? job!.equipmentTag.trim()
      : slot.equipmentTag.trim();
  final preset = (job?.presetTag.trim().isNotEmpty ?? false)
      ? job!.presetTag.trim()
      : slot.presetTag.trim();
  final product = (job?.fluid ?? '').trim().isNotEmpty
      ? job!.fluid.trim()
      : slot.product.trim();
  final serial = _meterSerialForDisplay(slot, job);
  final date = (job?.calibrationDate ?? '').trim();
  String? status;
  if (job != null) {
    if (job.status == CalibrationJobStatus.done) {
      status = 'Certificado Concluído';
    } else if (job.equipmentTag.trim().isNotEmpty ||
        job.serialNumber.trim().isNotEmpty) {
      status = 'Em andamento';
    } else {
      status = 'Calibração iniciada';
    }
  } else if (slot.isDataConfirmed) {
    status = 'Conferido';
  } else if (orphan) {
    status = 'Sem calibração (sobressalente)';
  } else if (!ready) {
    status = 'Cadastro pendente';
  }
  return [
    if (includeKind) calibrationKindLabel(calibrationKindFrom(slot.kind)),
    if (tag.isNotEmpty) 'TAG $tag',
    if (preset.isNotEmpty) 'Preset $preset',
    if (product.isNotEmpty) product,
    if (serial.isNotEmpty) 'N/S $serial',
    if (date.isNotEmpty) date,
    if (status != null) status,
    if (slot.isDivergent) 'Divergente',
    if (job != null && calibrationSlotJobMismatch(slot, job).isNotEmpty)
      'Difere da OS',
  ].join(' · ');
}

/// Identidade que a lista, a tela, o PDF, o livro e a etiqueta mostram:
/// tudo do certificado; o slot só completa campo vazio. Nunca mistura
/// N/S de um medidor com TAG/preset de outro.
CalibrationJob calibrationJobForCertificatePrint(
  CalibrationJob job, {
  OsCalibrationSlot? slot,
}) {
  if (slot == null) return job;
  String jobOrSlot(String jobVal, String slotVal) =>
      jobVal.trim().isNotEmpty ? jobVal.trim() : slotVal.trim();

  // Local do sistema: ILHA do slot/Excel vence BASPA/"In Loco" gravado no job.
  String preferInstallLocation() {
    final fromJob = job.installLocation.trim();
    final fromSlot = slot.installLocation.trim();
    bool ok(String value) =>
        isUsefulSystemLocal(
          value,
          site: job.site,
          clientName: job.clientName,
          serviceRequester: job.serviceRequester,
        ) &&
        !installLocationLooksLikePresetTag(job, value);
    final jobOk = ok(fromJob);
    final slotOk = ok(fromSlot);
    if (slotOk && !jobOk) return fromSlot;
    if (jobOk) return fromJob;
    if (slotOk) return fromSlot;
    return '';
  }

  final serial = _meterSerialForDisplay(slot, job);
  final tag = jobOrSlot(job.equipmentTag, slot.equipmentTag);
  final preset = jobOrSlot(job.presetTag, slot.presetTag);
  return job.copyWith(
    equipmentTag: tag,
    serialNumber: serial.isNotEmpty ? serial : job.serialNumber,
    manufacturer: jobOrSlot(job.manufacturer, slot.manufacturer),
    model: jobOrSlot(job.model, slot.model),
    workingPrinciple: jobOrSlot(job.workingPrinciple, slot.workingPrinciple),
    equipmentType: jobOrSlot(job.equipmentType, slot.equipmentType),
    presetTag: preset,
    presetManufacturer: jobOrSlot(
      job.presetManufacturer,
      slot.presetManufacturer,
    ),
    presetModel: jobOrSlot(job.presetModel, slot.presetModel),
    presetSerial: jobOrSlot(job.presetSerial, slot.presetSerial),
    systemType: jobOrSlot(job.systemType, slot.systemType),
    systemTag: jobOrSlot(job.systemTag, slot.systemTag),
    installLocation: preferInstallLocation(),
    fluid: jobOrSlot(job.fluid, slot.product),
    equipmentId: _equipmentIdForPrint(job, slot, tag: tag, serial: serial),
    systemId: _systemIdForPrint(job, slot, preset: preset),
  );
}

/// Id do cadastro só permanece se não apontar para outra TAG/N/S.
String _equipmentIdForPrint(
  CalibrationJob job,
  OsCalibrationSlot slot, {
  required String tag,
  required String serial,
}) {
  final id = job.equipmentId.trim().isNotEmpty
      ? job.equipmentId.trim()
      : slot.equipmentId.trim();
  if (id.isEmpty) return '';
  final client =
      ClientStore.instance.byId(job.clientId) ??
      ClientStore.instance.findMatch(
        cnpj: job.clientCnpj,
        name: job.clientName,
      );
  if (client == null) return id;
  ClientEquipment? item;
  for (final equipment in client.equipment) {
    if (equipment.id == id) {
      item = equipment;
      break;
    }
  }
  if (item == null) return id;
  final itemTag = item.tag.trim().toLowerCase();
  final itemSerial = item.serialNumber.trim().toLowerCase();
  final tagKey = tag.trim().toLowerCase();
  final serialKey = serial.trim().toLowerCase();
  if (tagKey.isNotEmpty && itemTag.isNotEmpty && itemTag != tagKey) return '';
  if (serialKey.isNotEmpty &&
      itemSerial.isNotEmpty &&
      itemSerial != serialKey) {
    return '';
  }
  return id;
}

String _systemIdForPrint(
  CalibrationJob job,
  OsCalibrationSlot slot, {
  required String preset,
}) {
  final id = job.systemId.trim().isNotEmpty
      ? job.systemId.trim()
      : slot.systemId.trim();
  if (id.isEmpty || preset.trim().isEmpty) return id;
  final client =
      ClientStore.instance.byId(job.clientId) ??
      ClientStore.instance.findMatch(
        cnpj: job.clientCnpj,
        name: job.clientName,
      );
  if (client == null) return id;
  for (final system in client.resolvedSystems) {
    if (system.id != id) continue;
    final assembly = system.assemblyTag.trim().toLowerCase();
    if (assembly.isNotEmpty && assembly != preset.trim().toLowerCase()) {
      return '';
    }
    return id;
  }
  return id;
}

List<VolumeRun> padVolumeRuns(List<VolumeRun> current, int count) {
  return _padRuns(current, count);
}

List<FlowPoint> padFlowPoints(
  List<FlowPoint> current,
  int count,
  int runCount,
) {
  final next = [...current];
  while (next.length < count) {
    next.add(
      FlowPoint(
        id: _id(),
        verification: [for (var r = 0; r < runCount; r++) VolumeRun(id: _id())],
      ),
    );
  }
  return [for (final point in next.take(count)) point.withRunCount(runCount)];
}

List<GenericPoint> padGenericPoints(
  List<GenericPoint> current,
  int count,
  int cycles,
) {
  final next = [...current];
  while (next.length < count) {
    next.add(GenericPoint(id: _id()));
  }
  return [
    for (final point in next.take(count))
      point.copyWith(cycles: _padCycles(point.cycles, cycles)),
  ];
}

List<VolumeRun> _padRuns(List<VolumeRun> current, int count) {
  final next = [...current];
  while (next.length < count) {
    next.add(VolumeRun(id: _id()));
  }
  return [for (final run in next.take(count)) run];
}

/// Corta corridas vazias além de [count], sem perder corrida já medida.
List<VolumeRun> _dropEmptyRunsAbove(List<VolumeRun> runs, int count) {
  final next = [...runs];
  for (var i = next.length - 1; i >= count && next.length > count; i--) {
    final run = next[i];
    if (run.objectVolume == null && run.standardVolume == null) {
      next.removeAt(i);
    }
  }
  return next;
}

List<GenericCycle> _padCycles(List<GenericCycle> current, int count) {
  final next = [...current];
  while (next.length < count) {
    next.add(const GenericCycle());
  }
  return [for (final cycle in next.take(count)) cycle];
}

List<VolumeRun> _runs(dynamic raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      VolumeRun.fromJson(Map<String, dynamic>.from(item as Map)),
  ];
}

String _defaultProcedure(CalibrationKind kind) {
  if (kind == CalibrationKind.telemetry) return telemetryProcedureDefault;
  return 'Comparação direta';
}

List<TelemetryChannel> _readTelemetryChannels(
  Map<String, dynamic> json,
  CalibrationKind kind,
) {
  final raw = json['telemetryChannels'];
  if (raw is List && raw.isNotEmpty) {
    return [
      for (final item in raw)
        TelemetryChannel.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
  }
  if (kind == CalibrationKind.telemetry) return defaultTelemetryChannels();
  return const [];
}

double _d(dynamic value, double fallback) {
  if (value is num) return value.toDouble();
  final parsed = parseBrNumber('$value');
  return parsed ?? fallback;
}

double? _dOrNull(dynamic value) {
  if (value == null || '$value'.trim().isEmpty) return null;
  if (value is num) return value.toDouble();
  return parseBrNumber('$value');
}

int _i(dynamic value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? fallback;
}

var _idSeq = 0;

String _id() {
  _idSeq += 1;
  return '${DateTime.now().microsecondsSinceEpoch}-$_idSeq';
}
