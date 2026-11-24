"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useMemo, useState, useTransition } from "react";
import { saveCalibracaoAction } from "@/app/(app)/calibracao/actions";
import {
  buildCalibrationWorkbench,
  CALIBRATION_KINDS,
  correctedMeterFactor,
  defaultMeasurementUnit,
  defaultWorkingPrinciple,
  formatCalibNumber,
  formatPercent,
  isGenericKind,
  isTelemetryKind,
  isTemperatureFamily,
  isVolumetricKind,
  meanOf,
  meterFactor,
  normalizeCalibrationKind,
  parseCalibNumber,
  pointsSectionHint,
  pointsSectionTitle,
  repeatabilityPercent,
  suggestedMeasurementUnits,
  volumetricErrorPercent,
} from "@/lib/campo-data";
import type { CampoStandard } from "@/lib/campo-data";

const inputClass =
  "mt-1 w-full rounded-xl border border-navy/15 bg-white px-3 py-2 text-sm text-navy outline-none focus:border-brass";

const STATUSES = [
  { value: "draft", label: "Rascunho" },
  { value: "inProgress", label: "Em andamento" },
  { value: "pendingReview", label: "Em revisão" },
  { value: "done", label: "Concluída" },
];

type RunDraft = {
  id: string;
  standardVolume: string;
  objectVolume: string;
  density: string;
  temperature: string;
};

type PointDraft = {
  id: string;
  flowRate: string;
  flowUnit: string;
  oldMeterFactor: string;
  verification: RunDraft[];
};

type CycleDraft = {
  id: string;
  standard: string;
  instrument: string;
  temperature: string;
};

type GenericPointDraft = {
  id: string;
  label: string;
  oldFactor: string;
  newValue: string;
  isConference: boolean;
  cycles: CycleDraft[];
};

type TelemetryTakeDraft = {
  id: string;
  standard: string;
  instrument: string;
};

type TelemetryChannelDraft = {
  id: string;
  key: string;
  label: string;
  unit: string;
  found: TelemetryTakeDraft[];
  left: TelemetryTakeDraft[];
};

type StandardDraft = {
  id: string;
  tag: string;
  description: string;
  certificate: string;
  validity: string;
  uncertainty: string;
  coverageK: string;
  serialNumber: string;
  manufacturer: string;
  model: string;
};

function newId(prefix: string) {
  return `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
}

function emptyRun(): RunDraft {
  return {
    id: newId("run"),
    standardVolume: "",
    objectVolume: "",
    density: "",
    temperature: "",
  };
}

function emptyPoint(): PointDraft {
  return {
    id: newId("pt"),
    flowRate: "",
    flowUnit: "L/min",
    oldMeterFactor: "",
    verification: [emptyRun(), emptyRun(), emptyRun()],
  };
}

function emptyCycle(): CycleDraft {
  return {
    id: newId("cyc"),
    standard: "",
    instrument: "",
    temperature: "",
  };
}

function emptyGenericPoint(cycleCount = 3): GenericPointDraft {
  return {
    id: newId("gpt"),
    label: "",
    oldFactor: "",
    newValue: "",
    isConference: false,
    cycles: Array.from({ length: Math.max(1, cycleCount) }, () => emptyCycle()),
  };
}

function emptyTake(): TelemetryTakeDraft {
  return { id: newId("take"), standard: "", instrument: "" };
}

function defaultTelemetryChannels(): TelemetryChannelDraft[] {
  return [
    {
      id: newId("ch"),
      key: "level",
      label: "Nível",
      unit: "mm",
      found: [emptyTake(), emptyTake(), emptyTake()],
      left: [emptyTake(), emptyTake(), emptyTake()],
    },
    {
      id: newId("ch"),
      key: "temperature",
      label: "Temperatura",
      unit: "°C",
      found: [emptyTake()],
      left: [emptyTake()],
    },
  ];
}

function text(v: unknown) {
  return String(v ?? "").trim();
}

function runsFromRaw(raw: unknown): RunDraft[] {
  if (!Array.isArray(raw) || raw.length === 0) {
    return [emptyRun(), emptyRun(), emptyRun()];
  }
  return raw.map((item, i) => {
    const r =
      item && typeof item === "object"
        ? (item as Record<string, unknown>)
        : {};
    return {
      id: text(r.id) || newId(`run${i}`),
      standardVolume: String(
        r.standardVolume ?? r.standard ?? r.padrao ?? "",
      ),
      objectVolume: String(
        r.objectVolume ?? r.meterVolume ?? r.instrument ?? "",
      ),
      density: String(r.density ?? ""),
      temperature: String(r.temperature ?? ""),
    };
  });
}

function pointsFromRaw(raw: unknown): PointDraft[] {
  if (!Array.isArray(raw) || raw.length === 0) return [emptyPoint()];
  return raw.map((item, i) => {
    const p =
      item && typeof item === "object"
        ? (item as Record<string, unknown>)
        : {};
    return {
      id: text(p.id) || newId(`pt${i}`),
      flowRate: String(p.flowRate ?? ""),
      flowUnit: text(p.flowUnit) || "L/min",
      oldMeterFactor: String(p.oldMeterFactor ?? ""),
      verification: runsFromRaw(p.verification),
    };
  });
}

function cyclesFromRaw(raw: unknown, fallback = 3): CycleDraft[] {
  if (!Array.isArray(raw) || raw.length === 0) {
    return Array.from({ length: fallback }, () => emptyCycle());
  }
  return raw.map((item, i) => {
    const c =
      item && typeof item === "object"
        ? (item as Record<string, unknown>)
        : {};
    return {
      id: text(c.id) || newId(`cyc${i}`),
      standard: String(c.standard ?? ""),
      instrument: String(c.instrument ?? ""),
      temperature: String(c.temperature ?? ""),
    };
  });
}

function genericPointsFromRaw(raw: unknown): GenericPointDraft[] {
  if (!Array.isArray(raw) || raw.length === 0) {
    return [
      emptyGenericPoint(),
      emptyGenericPoint(),
      emptyGenericPoint(),
    ];
  }
  return raw.map((item, i) => {
    const p =
      item && typeof item === "object"
        ? (item as Record<string, unknown>)
        : {};
    return {
      id: text(p.id) || newId(`gpt${i}`),
      label: text(p.label),
      oldFactor: String(p.oldFactor ?? ""),
      newValue: String(p.newValue ?? ""),
      isConference: p.isConference === true,
      cycles: cyclesFromRaw(p.cycles),
    };
  });
}

function takesFromRaw(raw: unknown, min = 1): TelemetryTakeDraft[] {
  if (!Array.isArray(raw) || raw.length === 0) {
    return Array.from({ length: min }, () => emptyTake());
  }
  return raw.map((item, i) => {
    const t =
      item && typeof item === "object"
        ? (item as Record<string, unknown>)
        : {};
    return {
      id: text(t.id) || newId(`take${i}`),
      standard: String(t.standard ?? ""),
      instrument: String(t.instrument ?? ""),
    };
  });
}

function telemetryFromRaw(raw: unknown): TelemetryChannelDraft[] {
  if (!Array.isArray(raw) || raw.length === 0) {
    return defaultTelemetryChannels();
  }
  return raw.map((item, i) => {
    const c =
      item && typeof item === "object"
        ? (item as Record<string, unknown>)
        : {};
    const key = text(c.key) || `ch${i}`;
    const minTakes = key === "level" ? 3 : 1;
    return {
      id: text(c.id) || newId(`ch${i}`),
      key,
      label: text(c.label) || (key === "level" ? "Nível" : key === "temperature" ? "Temperatura" : key),
      unit: text(c.unit) || (key === "level" ? "mm" : key === "temperature" ? "°C" : ""),
      found: takesFromRaw(c.found, minTakes),
      left: takesFromRaw(c.left, minTakes),
    };
  });
}

function standardsFromRaw(raw: unknown): StandardDraft[] {
  if (!Array.isArray(raw)) return [];
  return raw.map((item, i) => {
    const s =
      item && typeof item === "object"
        ? (item as Record<string, unknown>)
        : {};
    return {
      id: text(s.id) || newId(`std${i}`),
      tag: text(s.tag) || text(s.name),
      description: text(s.description) || text(s.type),
      certificate: text(s.certificate),
      validity: text(s.validity),
      uncertainty: text(s.uncertainty),
      coverageK: text(s.coverageK) || text(s.coverageFactor),
      serialNumber: text(s.serialNumber) || text(s.serial),
      manufacturer: text(s.manufacturer),
      model: text(s.model),
    };
  });
}

function serializeTakes(takes: TelemetryTakeDraft[]) {
  return takes
    .filter((t) => t.standard || t.instrument)
    .map((t) => ({
      standard: parseCalibNumber(t.standard),
      instrument: parseCalibNumber(t.instrument),
    }));
}

function buildPayload(input: {
  base: Record<string, unknown>;
  id: string;
  number: string;
  kind: string;
  status: string;
  clientName: string;
  equipmentTag: string;
  equipmentType: string;
  manufacturer: string;
  model: string;
  serialNumber: string;
  technicianName: string;
  calibrationDate: string;
  nextCalibrationDate: string;
  site: string;
  fluid: string;
  ambientTemp: string;
  humidity: string;
  pressure: string;
  workingPrinciple: string;
  measurementUnit: string;
  cycleCount: number;
  meterKFactorFound: string;
  meterKFactorLeft: string;
  measurementUncertainty: string;
  coverageFactor: string;
  effectiveDof: string;
  points: PointDraft[];
  genericPoints: GenericPointDraft[];
  telemetryChannels: TelemetryChannelDraft[];
  standards: StandardDraft[];
}): Record<string, unknown> {
  const kind = normalizeCalibrationKind(input.kind);
  const inverted = kind === "volumetricInverted";
  const volumetric = isVolumetricKind(kind);
  const telemetry = isTelemetryKind(kind);

  const points = volumetric
    ? input.points.map((pt) => {
        const verification = pt.verification
          .filter((r) => r.standardVolume || r.objectVolume)
          .map((r) => {
            const standardVolume = parseCalibNumber(r.standardVolume);
            const objectVolume = parseCalibNumber(r.objectVolume);
            return {
              id: r.id,
              standardVolume,
              objectVolume,
              meterVolume: objectVolume,
              density: parseCalibNumber(r.density),
              temperature: parseCalibNumber(r.temperature),
              isFilled: standardVolume != null || objectVolume != null,
            };
          });
        return {
          id: pt.id,
          flowRate: parseCalibNumber(pt.flowRate),
          flowUnit: pt.flowUnit || "L/min",
          oldMeterFactor: parseCalibNumber(pt.oldMeterFactor),
          verification,
          conferences: [],
        };
      })
    : [];

  const genericPoints = !volumetric && !telemetry
    ? input.genericPoints.map((pt) => ({
        id: pt.id,
        label: pt.label,
        oldFactor: parseCalibNumber(pt.oldFactor),
        newValue: parseCalibNumber(pt.newValue),
        isConference: pt.isConference || undefined,
        cycles: pt.cycles
          .filter((c) => c.standard || c.instrument || c.temperature)
          .map((c) => ({
            standard: parseCalibNumber(c.standard),
            instrument: parseCalibNumber(c.instrument),
            temperature: parseCalibNumber(c.temperature),
          })),
        conferences: [],
      }))
    : [];

  const telemetryChannels = telemetry
    ? input.telemetryChannels.map((ch) => ({
        id: ch.id,
        key: ch.key,
        label: ch.label,
        unit: ch.unit,
        found: serializeTakes(ch.found),
        left: serializeTakes(ch.left),
      }))
    : [];

  return {
    ...input.base,
    id: input.id,
    number: input.number,
    kind,
    status: input.status,
    clientName: input.clientName,
    equipmentTag: input.equipmentTag,
    equipmentType: input.equipmentType,
    manufacturer: input.manufacturer,
    model: input.model,
    serialNumber: input.serialNumber,
    technicianName: input.technicianName,
    fieldTechnicianName: input.technicianName,
    calibrationDate: input.calibrationDate,
    nextCalibrationDate: input.nextCalibrationDate,
    site: input.site,
    fluid: input.fluid,
    ambientTemp: input.ambientTemp,
    humidity: input.humidity,
    pressure: input.pressure,
    workingPrinciple: input.workingPrinciple,
    measurementUnit: input.measurementUnit,
    cycleCount: input.cycleCount,
    meterKFactorFound: input.meterKFactorFound,
    meterKFactorLeft: input.meterKFactorLeft,
    measurementUncertainty: input.measurementUncertainty,
    coverageFactor: input.coverageFactor,
    effectiveDof: input.effectiveDof,
    points,
    genericPoints,
    telemetryChannels,
    standards: input.standards.map((s) => ({
      id: s.id,
      tag: s.tag,
      description: s.description,
      certificate: s.certificate,
      validity: s.validity,
      uncertainty: s.uncertainty,
      coverageK: s.coverageK,
      serialNumber: s.serialNumber,
      manufacturer: s.manufacturer,
      model: s.model,
    })),
    flowCount: points.length,
    runCount: points.reduce((n, p) => n + p.verification.length, 0),
    _invertedMeterFactor: inverted,
  };
}

export function CalibEditor({
  initial,
  catalogStandards,
  isNew = false,
}: {
  initial: Record<string, unknown>;
  catalogStandards: CampoStandard[];
  isNew?: boolean;
}) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [ok, setOk] = useState(false);

  const initialKind = normalizeCalibrationKind(text(initial.kind) || "volumetric");

  const [id] = useState(text(initial.id) || `calib-${Date.now()}`);
  const [number, setNumber] = useState(text(initial.number));
  const [kind, setKind] = useState(initialKind);
  const [status, setStatus] = useState(text(initial.status) || "draft");
  const [clientName, setClientName] = useState(text(initial.clientName));
  const [equipmentTag, setEquipmentTag] = useState(text(initial.equipmentTag));
  const [equipmentType, setEquipmentType] = useState(
    text(initial.equipmentType),
  );
  const [manufacturer, setManufacturer] = useState(text(initial.manufacturer));
  const [model, setModel] = useState(text(initial.model));
  const [serialNumber, setSerialNumber] = useState(text(initial.serialNumber));
  const [technicianName, setTechnicianName] = useState(
    text(initial.technicianName) || text(initial.fieldTechnicianName),
  );
  const [calibrationDate, setCalibrationDate] = useState(
    text(initial.calibrationDate),
  );
  const [nextCalibrationDate, setNextCalibrationDate] = useState(
    text(initial.nextCalibrationDate),
  );
  const [site, setSite] = useState(text(initial.site));
  const [fluid, setFluid] = useState(text(initial.fluid));
  const [ambientTemp, setAmbientTemp] = useState(text(initial.ambientTemp));
  const [humidity, setHumidity] = useState(text(initial.humidity));
  const [pressure, setPressure] = useState(text(initial.pressure));
  const [workingPrinciple, setWorkingPrinciple] = useState(
    text(initial.workingPrinciple) ||
      defaultWorkingPrinciple(initialKind, text(initial.equipmentType)),
  );
  const [measurementUnit, setMeasurementUnit] = useState(
    text(initial.measurementUnit) || defaultMeasurementUnit(initialKind),
  );
  const [cycleCount, setCycleCount] = useState(() => {
    const n = Number(initial.cycleCount);
    return Number.isFinite(n) && n > 0 ? Math.floor(n) : 3;
  });
  const [meterKFactorFound, setMeterKFactorFound] = useState(
    text(initial.meterKFactorFound) || text(initial.meterKFactor),
  );
  const [meterKFactorLeft, setMeterKFactorLeft] = useState(
    text(initial.meterKFactorLeft),
  );
  const [measurementUncertainty, setMeasurementUncertainty] = useState(
    text(initial.measurementUncertainty),
  );
  const [coverageFactor, setCoverageFactor] = useState(
    text(initial.coverageFactor),
  );
  const [effectiveDof, setEffectiveDof] = useState(text(initial.effectiveDof));
  const [points, setPoints] = useState<PointDraft[]>(() =>
    pointsFromRaw(initial.points),
  );
  const [genericPoints, setGenericPoints] = useState<GenericPointDraft[]>(() =>
    genericPointsFromRaw(initial.genericPoints),
  );
  const [telemetryChannels, setTelemetryChannels] = useState<
    TelemetryChannelDraft[]
  >(() => telemetryFromRaw(initial.telemetryChannels));
  const [standards, setStandards] = useState<StandardDraft[]>(() =>
    standardsFromRaw(initial.standards),
  );

  const volumetric = isVolumetricKind(kind);
  const telemetry = isTelemetryKind(kind);
  const generic = isGenericKind(kind);
  const tempFamily = isTemperatureFamily(kind);
  const inverted = kind === "volumetricInverted";
  const unitSuggestions = suggestedMeasurementUnits(kind);

  function applyKind(nextRaw: string) {
    const next = normalizeCalibrationKind(nextRaw);
    setKind(next);
    setMeasurementUnit((prev) => {
      const prevDefault = defaultMeasurementUnit(kind);
      if (!prev || prev === prevDefault) return defaultMeasurementUnit(next);
      return prev;
    });
    setWorkingPrinciple((prev) => {
      const prevDefault = defaultWorkingPrinciple(kind, equipmentType);
      if (!prev || prev === prevDefault) {
        return defaultWorkingPrinciple(next, equipmentType);
      }
      return prev;
    });
    if (isVolumetricKind(next)) {
      setPoints((prev) => (prev.length ? prev : [emptyPoint(), emptyPoint()]));
    } else if (isTelemetryKind(next)) {
      setTelemetryChannels((prev) =>
        prev.length ? prev : defaultTelemetryChannels(),
      );
      if (!equipmentType.trim()) {
        setEquipmentType("Medidor de Nível tipo Servo Operado");
      }
    } else {
      setGenericPoints((prev) =>
        prev.length
          ? prev
          : [emptyGenericPoint(3), emptyGenericPoint(3), emptyGenericPoint(3)],
      );
    }
  }

  const livePayload = useMemo(
    () =>
      buildPayload({
        base: initial,
        id,
        number,
        kind,
        status,
        clientName,
        equipmentTag,
        equipmentType,
        manufacturer,
        model,
        serialNumber,
        technicianName,
        calibrationDate,
        nextCalibrationDate,
        site,
        fluid,
        ambientTemp,
        humidity,
        pressure,
        workingPrinciple,
        measurementUnit,
        cycleCount,
        meterKFactorFound,
        meterKFactorLeft,
        measurementUncertainty,
        coverageFactor,
        effectiveDof,
        points,
        genericPoints,
        telemetryChannels,
        standards,
      }),
    [
      initial,
      id,
      number,
      kind,
      status,
      clientName,
      equipmentTag,
      equipmentType,
      manufacturer,
      model,
      serialNumber,
      technicianName,
      calibrationDate,
      nextCalibrationDate,
      site,
      fluid,
      ambientTemp,
      humidity,
      pressure,
      workingPrinciple,
      measurementUnit,
      cycleCount,
      meterKFactorFound,
      meterKFactorLeft,
      measurementUncertainty,
      coverageFactor,
      effectiveDof,
      points,
      genericPoints,
      telemetryChannels,
      standards,
    ],
  );

  const preview = useMemo(
    () => buildCalibrationWorkbench(livePayload),
    [livePayload],
  );

  function updatePoint(index: number, patch: Partial<PointDraft>) {
    setPoints((prev) =>
      prev.map((p, i) => (i === index ? { ...p, ...patch } : p)),
    );
  }

  function updateRun(
    pointIndex: number,
    runIndex: number,
    patch: Partial<RunDraft>,
  ) {
    setPoints((prev) =>
      prev.map((p, i) => {
        if (i !== pointIndex) return p;
        return {
          ...p,
          verification: p.verification.map((r, j) =>
            j === runIndex ? { ...r, ...patch } : r,
          ),
        };
      }),
    );
  }

  function updateGenericPoint(
    index: number,
    patch: Partial<GenericPointDraft>,
  ) {
    setGenericPoints((prev) =>
      prev.map((p, i) => (i === index ? { ...p, ...patch } : p)),
    );
  }

  function updateGenericCycle(
    pointIndex: number,
    cycleIndex: number,
    patch: Partial<CycleDraft>,
  ) {
    setGenericPoints((prev) =>
      prev.map((p, i) => {
        if (i !== pointIndex) return p;
        return {
          ...p,
          cycles: p.cycles.map((c, j) =>
            j === cycleIndex ? { ...c, ...patch } : c,
          ),
        };
      }),
    );
  }

  function updateTelemetryTake(
    channelIndex: number,
    side: "found" | "left",
    takeIndex: number,
    patch: Partial<TelemetryTakeDraft>,
  ) {
    setTelemetryChannels((prev) =>
      prev.map((ch, i) => {
        if (i !== channelIndex) return ch;
        return {
          ...ch,
          [side]: ch[side].map((t, j) =>
            j === takeIndex ? { ...t, ...patch } : t,
          ),
        };
      }),
    );
  }

  function addCatalogStandard(std: CampoStandard) {
    setStandards((prev) => {
      if (prev.some((s) => s.serialNumber && s.serialNumber === std.serial)) {
        return prev;
      }
      return [
        ...prev,
        {
          id: newId("std"),
          tag: std.name,
          description: std.type,
          certificate: std.certificate,
          validity: std.validity,
          uncertainty: text(std.raw.uncertainty) || "",
          coverageK: text(std.raw.coverageK) || "",
          serialNumber: std.serial,
          manufacturer: "",
          model: "",
        },
      ];
    });
  }

  function syncCycleCount(count: number) {
    const n = Math.max(1, Math.min(12, count));
    setCycleCount(n);
    setGenericPoints((prev) =>
      prev.map((pt) => {
        const cycles = [...pt.cycles];
        while (cycles.length < n) cycles.push(emptyCycle());
        while (cycles.length > n) cycles.pop();
        return { ...pt, cycles };
      }),
    );
  }

  return (
    <form
      className="space-y-5"
      onSubmit={(e) => {
        e.preventDefault();
        setError(null);
        setOk(false);
        startTransition(async () => {
          const result = await saveCalibracaoAction({
            id,
            number,
            kind,
            clientName,
            payload: livePayload,
          });
          if (!result.ok) {
            setError(result.error || "Falha ao salvar.");
            return;
          }
          setOk(true);
          if (isNew && result.id) {
            router.push(`/calibracao/${result.id}`);
          }
          router.refresh();
        });
      }}
    >
      <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
              Cadastro
            </p>
            <h2 className="mt-1 font-serif text-xl text-navy">
              Dados do certificado
            </h2>
          </div>
          <div className="flex flex-wrap gap-2">
            <button
              type="submit"
              disabled={pending || !number.trim()}
              className="rounded-xl bg-brass px-4 py-2.5 text-sm font-semibold text-navy hover:bg-brass-2 disabled:opacity-60"
            >
              {pending ? "Salvando na planilha…" : "Salvar (app + escritório)"}
            </button>
            <Link
              href="/calibracao"
              className="rounded-xl border border-navy/15 bg-white px-4 py-2.5 text-sm font-medium text-navy hover:bg-paper"
            >
              Voltar
            </Link>
          </div>
        </div>
        {error ? <p className="mt-3 text-sm text-red-700">{error}</p> : null}
        {ok ? (
          <p className="mt-3 text-sm text-ok">
            Salvo na planilha — o GS Campo recebe no sync.
          </p>
        ) : null}

        <div className="mt-4 grid gap-3 md:grid-cols-2 lg:grid-cols-3">
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Número *
            </span>
            <input
              required
              value={number}
              onChange={(e) => setNumber(e.target.value)}
              className={inputClass}
            />
          </label>
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Tipo
            </span>
            <select
              value={kind}
              onChange={(e) => applyKind(e.target.value)}
              className={inputClass}
            >
              {CALIBRATION_KINDS.map((k) => (
                <option key={k.value} value={k.value}>
                  {k.label}
                </option>
              ))}
            </select>
          </label>
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Status
            </span>
            <select
              value={status}
              onChange={(e) => setStatus(e.target.value)}
              className={inputClass}
            >
              {STATUSES.map((s) => (
                <option key={s.value} value={s.value}>
                  {s.label}
                </option>
              ))}
            </select>
          </label>
          <label className="block text-sm md:col-span-2">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Cliente
            </span>
            <input
              value={clientName}
              onChange={(e) => setClientName(e.target.value)}
              className={inputClass}
            />
          </label>
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Técnico
            </span>
            <input
              value={technicianName}
              onChange={(e) => setTechnicianName(e.target.value)}
              className={inputClass}
            />
          </label>
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              TAG
            </span>
            <input
              value={equipmentTag}
              onChange={(e) => setEquipmentTag(e.target.value)}
              className={inputClass}
            />
          </label>
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Tipo equipamento
            </span>
            <input
              value={equipmentType}
              onChange={(e) => setEquipmentType(e.target.value)}
              className={inputClass}
            />
          </label>
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Princípio de funcionamento
            </span>
            <input
              value={workingPrinciple}
              onChange={(e) => setWorkingPrinciple(e.target.value)}
              className={inputClass}
              placeholder={defaultWorkingPrinciple(kind, equipmentType)}
            />
          </label>
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              N/S
            </span>
            <input
              value={serialNumber}
              onChange={(e) => setSerialNumber(e.target.value)}
              className={inputClass}
            />
          </label>
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Fabricante
            </span>
            <input
              value={manufacturer}
              onChange={(e) => setManufacturer(e.target.value)}
              className={inputClass}
            />
          </label>
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Modelo
            </span>
            <input
              value={model}
              onChange={(e) => setModel(e.target.value)}
              className={inputClass}
            />
          </label>
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Calibrado em
            </span>
            <input
              value={calibrationDate}
              onChange={(e) => setCalibrationDate(e.target.value)}
              className={inputClass}
              placeholder="AAAA-MM-DD"
            />
          </label>
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Próxima
            </span>
            <input
              value={nextCalibrationDate}
              onChange={(e) => setNextCalibrationDate(e.target.value)}
              className={inputClass}
              placeholder="AAAA-MM-DD"
            />
          </label>
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Local
            </span>
            <input
              value={site}
              onChange={(e) => setSite(e.target.value)}
              className={inputClass}
            />
          </label>
          {volumetric ? (
            <label className="block text-sm">
              <span className="text-[11px] uppercase tracking-wide text-navy/45">
                Fluido
              </span>
              <input
                value={fluid}
                onChange={(e) => setFluid(e.target.value)}
                className={inputClass}
              />
            </label>
          ) : (
            <label className="block text-sm">
              <span className="text-[11px] uppercase tracking-wide text-navy/45">
                Unidade de medição
              </span>
              <input
                list={`meas-units-${kind}`}
                value={measurementUnit}
                onChange={(e) => setMeasurementUnit(e.target.value)}
                className={inputClass}
              />
              <datalist id={`meas-units-${kind}`}>
                {unitSuggestions.map((u) => (
                  <option key={u} value={u} />
                ))}
              </datalist>
            </label>
          )}
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Temp. amb.
            </span>
            <input
              value={ambientTemp}
              onChange={(e) => setAmbientTemp(e.target.value)}
              className={inputClass}
            />
          </label>
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Umidade
            </span>
            <input
              value={humidity}
              onChange={(e) => setHumidity(e.target.value)}
              className={inputClass}
            />
          </label>
          {volumetric ? (
            <label className="block text-sm">
              <span className="text-[11px] uppercase tracking-wide text-navy/45">
                Pressão
              </span>
              <input
                value={pressure}
                onChange={(e) => setPressure(e.target.value)}
                className={inputClass}
              />
            </label>
          ) : null}
        </div>
      </section>

      {volumetric ? (
        <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
          <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
            Resultados
          </p>
          <h2 className="mt-1 font-serif text-xl text-navy">
            Fator K e incerteza
          </h2>
          <div className="mt-4 grid gap-3 md:grid-cols-2 lg:grid-cols-3">
            <label className="block text-sm">
              <span className="text-[11px] uppercase tracking-wide text-navy/45">
                Fator K encontrado
              </span>
              <input
                value={meterKFactorFound}
                onChange={(e) => setMeterKFactorFound(e.target.value)}
                className={inputClass}
              />
            </label>
            <label className="block text-sm">
              <span className="text-[11px] uppercase tracking-wide text-navy/45">
                Fator K deixado
              </span>
              <input
                value={meterKFactorLeft}
                onChange={(e) => setMeterKFactorLeft(e.target.value)}
                className={inputClass}
              />
            </label>
            <label className="block text-sm">
              <span className="text-[11px] uppercase tracking-wide text-navy/45">
                Incerteza expandida
              </span>
              <input
                value={measurementUncertainty}
                onChange={(e) => setMeasurementUncertainty(e.target.value)}
                className={inputClass}
                placeholder="ex.: 0,12"
              />
            </label>
            <label className="block text-sm">
              <span className="text-[11px] uppercase tracking-wide text-navy/45">
                Fator de cobertura k
              </span>
              <input
                value={coverageFactor}
                onChange={(e) => setCoverageFactor(e.target.value)}
                className={inputClass}
                placeholder="ex.: 2"
              />
            </label>
            <label className="block text-sm">
              <span className="text-[11px] uppercase tracking-wide text-navy/45">
                ν_eff
              </span>
              <input
                value={effectiveDof}
                onChange={(e) => setEffectiveDof(e.target.value)}
                className={inputClass}
              />
            </label>
          </div>
          {preview.linearityPct != null ? (
            <p className="mt-3 text-sm text-navy/55">
              Linearidade calculada:{" "}
              <strong className="text-navy">
                {formatPercent(preview.linearityPct, 3)}
              </strong>
            </p>
          ) : null}
        </section>
      ) : (
        <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
          <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
            Resultados
          </p>
          <h2 className="mt-1 font-serif text-xl text-navy">Incerteza</h2>
          <div className="mt-4 grid gap-3 md:grid-cols-2 lg:grid-cols-3">
            <label className="block text-sm">
              <span className="text-[11px] uppercase tracking-wide text-navy/45">
                Incerteza expandida
              </span>
              <input
                value={measurementUncertainty}
                onChange={(e) => setMeasurementUncertainty(e.target.value)}
                className={inputClass}
                placeholder="ex.: 0,12"
              />
            </label>
            <label className="block text-sm">
              <span className="text-[11px] uppercase tracking-wide text-navy/45">
                Fator de cobertura k
              </span>
              <input
                value={coverageFactor}
                onChange={(e) => setCoverageFactor(e.target.value)}
                className={inputClass}
                placeholder="ex.: 2"
              />
            </label>
            <label className="block text-sm">
              <span className="text-[11px] uppercase tracking-wide text-navy/45">
                ν_eff
              </span>
              <input
                value={effectiveDof}
                onChange={(e) => setEffectiveDof(e.target.value)}
                className={inputClass}
              />
            </label>
          </div>
        </section>
      )}

      <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
        <div className="flex flex-wrap items-end justify-between gap-3">
          <div>
            <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
              Padrões
            </p>
            <h2 className="mt-1 font-serif text-xl text-navy">
              Usados nesta calibração
            </h2>
          </div>
        </div>
        {catalogStandards.length > 0 ? (
          <div className="mt-3 flex flex-wrap gap-2">
            {catalogStandards.slice(0, 40).map((std) => (
              <button
                key={std.id}
                type="button"
                onClick={() => addCatalogStandard(std)}
                className="rounded-xl border border-navy/12 bg-paper px-3 py-1.5 text-xs font-medium text-navy hover:border-brass/40"
              >
                + {std.name || std.serial || std.id}
              </button>
            ))}
          </div>
        ) : null}
        {standards.length === 0 ? (
          <p className="mt-4 text-sm text-muted">
            Nenhum padrão selecionado — use os chips do cadastro acima.
          </p>
        ) : (
          <ul className="mt-4 space-y-2">
            {standards.map((std, index) => (
              <li
                key={std.id}
                className="flex flex-wrap items-center justify-between gap-2 rounded-2xl border border-navy/10 bg-paper/70 px-4 py-3"
              >
                <div>
                  <p className="font-medium text-navy">{std.tag || "Padrão"}</p>
                  <p className="text-xs text-navy/50">
                    {[
                      std.description,
                      std.serialNumber && `N/S ${std.serialNumber}`,
                      std.certificate && `Cert. ${std.certificate}`,
                      std.uncertainty && `U ${std.uncertainty}`,
                    ]
                      .filter(Boolean)
                      .join(" · ")}
                  </p>
                </div>
                <button
                  type="button"
                  onClick={() =>
                    setStandards((prev) => prev.filter((_, i) => i !== index))
                  }
                  className="text-xs font-medium text-navy/45 hover:text-red-700"
                >
                  Remover
                </button>
              </li>
            ))}
          </ul>
        )}
      </section>

      {volumetric ? (
        <section className="space-y-4">
          <div className="flex flex-wrap items-end justify-between gap-3">
            <div>
              <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
                {pointsSectionTitle(kind)}
              </p>
              <h2 className="mt-1 font-serif text-xl text-navy">
                Corridas e cálculo de Mf
              </h2>
              <p className="mt-1 text-sm text-navy/55">
                {pointsSectionHint(kind)}
              </p>
            </div>
            <button
              type="button"
              onClick={() => setPoints((prev) => [...prev, emptyPoint()])}
              className="rounded-xl border border-navy/15 bg-white px-3 py-2 text-sm font-semibold text-navy hover:border-brass/40"
            >
              + Ponto
            </button>
          </div>

          {points.map((point, pointIndex) => {
            const factors = point.verification
              .map((r) =>
                meterFactor(
                  parseCalibNumber(r.standardVolume),
                  parseCalibNumber(r.objectVolume),
                  inverted,
                ),
              )
              .filter((v): v is number => v != null);
            const meanMf = meanOf(factors);
            const old = parseCalibNumber(point.oldMeterFactor);
            const suggested =
              old != null && meanMf != null
                ? correctedMeterFactor(old, meanMf)
                : null;
            const rep = repeatabilityPercent(factors);

            return (
              <article
                key={point.id}
                className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6"
              >
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <h3 className="font-serif text-lg text-navy">
                    Ponto {pointIndex + 1}
                  </h3>
                  {points.length > 1 ? (
                    <button
                      type="button"
                      onClick={() =>
                        setPoints((prev) =>
                          prev.filter((_, i) => i !== pointIndex),
                        )
                      }
                      className="text-xs font-medium text-navy/45 hover:text-red-700"
                    >
                      Remover ponto
                    </button>
                  ) : null}
                </div>

                <div className="mt-3 grid gap-3 md:grid-cols-3">
                  <label className="block text-sm">
                    <span className="text-[11px] uppercase tracking-wide text-navy/45">
                      Vazão
                    </span>
                    <input
                      value={point.flowRate}
                      onChange={(e) =>
                        updatePoint(pointIndex, { flowRate: e.target.value })
                      }
                      className={inputClass}
                    />
                  </label>
                  <label className="block text-sm">
                    <span className="text-[11px] uppercase tracking-wide text-navy/45">
                      Unidade
                    </span>
                    <input
                      value={point.flowUnit}
                      onChange={(e) =>
                        updatePoint(pointIndex, { flowUnit: e.target.value })
                      }
                      className={inputClass}
                    />
                  </label>
                  <label className="block text-sm">
                    <span className="text-[11px] uppercase tracking-wide text-navy/45">
                      Mf antigo
                    </span>
                    <input
                      value={point.oldMeterFactor}
                      onChange={(e) =>
                        updatePoint(pointIndex, {
                          oldMeterFactor: e.target.value,
                        })
                      }
                      className={inputClass}
                    />
                  </label>
                </div>

                <div className="mt-3 flex flex-wrap gap-2 text-sm">
                  <span className="rounded-xl bg-paper px-3 py-1.5">
                    Mf médio {formatCalibNumber(meanMf, 6)}
                  </span>
                  <span className="rounded-xl bg-paper px-3 py-1.5">
                    Rep. {formatPercent(rep, 3)}
                  </span>
                  <span className="rounded-xl bg-navy px-3 py-1.5 font-semibold text-brass">
                    Novo {formatCalibNumber(suggested, 6)}
                  </span>
                </div>

                <div className="mt-4 space-y-2">
                  <div className="flex items-center justify-between">
                    <p className="text-xs font-semibold uppercase tracking-wide text-navy/45">
                      Corridas de verificação
                    </p>
                    <button
                      type="button"
                      onClick={() =>
                        updatePoint(pointIndex, {
                          verification: [...point.verification, emptyRun()],
                        })
                      }
                      className="text-xs font-semibold text-navy/60 hover:text-navy"
                    >
                      + Corrida
                    </button>
                  </div>
                  {point.verification.map((run, runIndex) => {
                    const std = parseCalibNumber(run.standardVolume);
                    const obj = parseCalibNumber(run.objectVolume);
                    const mf = meterFactor(std, obj, inverted);
                    const err = volumetricErrorPercent(std, obj, inverted);
                    return (
                      <div
                        key={run.id}
                        className="grid gap-2 rounded-2xl border border-navy/10 bg-paper/50 p-3 md:grid-cols-6"
                      >
                        <label className="block text-xs md:col-span-1">
                          <span className="text-navy/45">Padrão</span>
                          <input
                            value={run.standardVolume}
                            onChange={(e) =>
                              updateRun(pointIndex, runIndex, {
                                standardVolume: e.target.value,
                              })
                            }
                            className={inputClass}
                          />
                        </label>
                        <label className="block text-xs md:col-span-1">
                          <span className="text-navy/45">Instrumento</span>
                          <input
                            value={run.objectVolume}
                            onChange={(e) =>
                              updateRun(pointIndex, runIndex, {
                                objectVolume: e.target.value,
                              })
                            }
                            className={inputClass}
                          />
                        </label>
                        <label className="block text-xs">
                          <span className="text-navy/45">ρ</span>
                          <input
                            value={run.density}
                            onChange={(e) =>
                              updateRun(pointIndex, runIndex, {
                                density: e.target.value,
                              })
                            }
                            className={inputClass}
                          />
                        </label>
                        <label className="block text-xs">
                          <span className="text-navy/45">T</span>
                          <input
                            value={run.temperature}
                            onChange={(e) =>
                              updateRun(pointIndex, runIndex, {
                                temperature: e.target.value,
                              })
                            }
                            className={inputClass}
                          />
                        </label>
                        <div className="flex items-end pb-2 text-xs font-semibold text-navy">
                          Mf {formatCalibNumber(mf, 6)}
                        </div>
                        <div className="flex items-end justify-between gap-2 pb-2 text-xs text-navy/70">
                          <span>{formatPercent(err, 3)}</span>
                          {point.verification.length > 1 ? (
                            <button
                              type="button"
                              onClick={() =>
                                updatePoint(pointIndex, {
                                  verification: point.verification.filter(
                                    (_, i) => i !== runIndex,
                                  ),
                                })
                              }
                              className="text-navy/40 hover:text-red-700"
                            >
                              ×
                            </button>
                          ) : null}
                        </div>
                      </div>
                    );
                  })}
                </div>
              </article>
            );
          })}
        </section>
      ) : null}

      {telemetry ? (
        <section className="space-y-4">
          <div>
            <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
              {pointsSectionTitle(kind)}
            </p>
            <h2 className="mt-1 font-serif text-xl text-navy">
              Encontrado e deixado
            </h2>
            <p className="mt-1 text-sm text-navy/55">
              {pointsSectionHint(kind)}
            </p>
          </div>

          {(["found", "left"] as const).map((side) => (
            <div key={side} className="space-y-3">
              <h3 className="font-serif text-lg text-navy">
                {side === "found" ? "Dados encontrados" : "Dados deixados"}
              </h3>
              {telemetryChannels.map((channel, channelIndex) => (
                <article
                  key={`${channel.id}-${side}`}
                  className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6"
                >
                  <div className="flex flex-wrap items-end gap-3">
                    <label className="block min-w-[10rem] flex-1 text-sm">
                      <span className="text-[11px] uppercase tracking-wide text-navy/45">
                        Canal
                      </span>
                      <input
                        value={channel.label}
                        onChange={(e) =>
                          setTelemetryChannels((prev) =>
                            prev.map((ch, i) =>
                              i === channelIndex
                                ? { ...ch, label: e.target.value }
                                : ch,
                            ),
                          )
                        }
                        className={inputClass}
                      />
                    </label>
                    <label className="block w-28 text-sm">
                      <span className="text-[11px] uppercase tracking-wide text-navy/45">
                        Unidade
                      </span>
                      <input
                        value={channel.unit}
                        onChange={(e) =>
                          setTelemetryChannels((prev) =>
                            prev.map((ch, i) =>
                              i === channelIndex
                                ? { ...ch, unit: e.target.value }
                                : ch,
                            ),
                          )
                        }
                        className={inputClass}
                      />
                    </label>
                    <button
                      type="button"
                      onClick={() =>
                        setTelemetryChannels((prev) =>
                          prev.map((ch, i) =>
                            i === channelIndex
                              ? {
                                  ...ch,
                                  [side]: [...ch[side], emptyTake()],
                                }
                              : ch,
                          ),
                        )
                      }
                      className="rounded-xl border border-navy/15 px-3 py-2 text-xs font-semibold text-navy"
                    >
                      + Tomada
                    </button>
                  </div>
                  <div className="mt-3 space-y-2">
                    {channel[side].map((take, takeIndex) => {
                      const std = parseCalibNumber(take.standard);
                      const inst = parseCalibNumber(take.instrument);
                      const err =
                        std != null && inst != null
                          ? Math.abs(inst - std)
                          : null;
                      return (
                        <div
                          key={take.id}
                          className="grid gap-2 rounded-2xl border border-navy/10 bg-paper/50 p-3 md:grid-cols-4"
                        >
                          <label className="block text-xs">
                            <span className="text-navy/45">Padrão</span>
                            <input
                              value={take.standard}
                              onChange={(e) =>
                                updateTelemetryTake(
                                  channelIndex,
                                  side,
                                  takeIndex,
                                  { standard: e.target.value },
                                )
                              }
                              className={inputClass}
                            />
                          </label>
                          <label className="block text-xs">
                            <span className="text-navy/45">Instrumento</span>
                            <input
                              value={take.instrument}
                              onChange={(e) =>
                                updateTelemetryTake(
                                  channelIndex,
                                  side,
                                  takeIndex,
                                  { instrument: e.target.value },
                                )
                              }
                              className={inputClass}
                            />
                          </label>
                          <div className="flex items-end pb-2 text-xs font-semibold text-navy">
                            Erro {formatCalibNumber(err, 3)}
                            {channel.unit ? ` ${channel.unit}` : ""}
                          </div>
                          {channel[side].length > 1 ? (
                            <div className="flex items-end justify-end pb-2">
                              <button
                                type="button"
                                onClick={() =>
                                  setTelemetryChannels((prev) =>
                                    prev.map((ch, i) =>
                                      i === channelIndex
                                        ? {
                                            ...ch,
                                            [side]: ch[side].filter(
                                              (_, j) => j !== takeIndex,
                                            ),
                                          }
                                        : ch,
                                    ),
                                  )
                                }
                                className="text-xs text-navy/40 hover:text-red-700"
                              >
                                Remover
                              </button>
                            </div>
                          ) : (
                            <div />
                          )}
                        </div>
                      );
                    })}
                  </div>
                </article>
              ))}
            </div>
          ))}
        </section>
      ) : null}

      {generic ? (
        <section className="space-y-4">
          <div className="flex flex-wrap items-end justify-between gap-3">
            <div>
              <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
                {pointsSectionTitle(kind)}
              </p>
              <h2 className="mt-1 font-serif text-xl text-navy">
                {tempFamily
                  ? "Ciclos (passagens) e pontos"
                  : kind === "density"
                    ? "Pontos por produto"
                    : "Pontos e leituras"}
              </h2>
              <p className="mt-1 text-sm text-navy/55">
                {pointsSectionHint(kind)}
              </p>
            </div>
            <div className="flex flex-wrap items-center gap-2">
              <label className="flex items-center gap-2 text-sm text-navy/70">
                <span className="text-[11px] uppercase tracking-wide text-navy/45">
                  Leituras / ciclo
                </span>
                <input
                  type="number"
                  min={1}
                  max={12}
                  value={cycleCount}
                  onChange={(e) =>
                    syncCycleCount(Number(e.target.value) || 1)
                  }
                  className="w-16 rounded-xl border border-navy/15 bg-white px-2 py-1.5 text-sm"
                />
              </label>
              <button
                type="button"
                onClick={() =>
                  setGenericPoints((prev) => [
                    ...prev,
                    emptyGenericPoint(cycleCount),
                  ])
                }
                className="rounded-xl border border-navy/15 bg-white px-3 py-2 text-sm font-semibold text-navy hover:border-brass/40"
              >
                {tempFamily ? "+ Ciclo" : "+ Ponto"}
              </button>
            </div>
          </div>

          {genericPoints.map((point, pointIndex) => {
            const errors = point.cycles
              .map((c) => {
                const s = parseCalibNumber(c.standard);
                const i = parseCalibNumber(c.instrument);
                return s != null && i != null ? i - s : null;
              })
              .filter((v): v is number => v != null);
            const meanErr = meanOf(errors);

            return (
              <article
                key={point.id}
                className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6"
              >
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <h3 className="font-serif text-lg text-navy">
                    {tempFamily
                      ? `Ciclo ${pointIndex + 1}`
                      : `Ponto ${pointIndex + 1}`}
                    {point.label ? ` — ${point.label}` : ""}
                  </h3>
                  {genericPoints.length > 1 ? (
                    <button
                      type="button"
                      onClick={() =>
                        setGenericPoints((prev) =>
                          prev.filter((_, i) => i !== pointIndex),
                        )
                      }
                      className="text-xs font-medium text-navy/45 hover:text-red-700"
                    >
                      Remover
                    </button>
                  ) : null}
                </div>

                <div className="mt-3 grid gap-3 md:grid-cols-2 lg:grid-cols-4">
                  <label className="block text-sm">
                    <span className="text-[11px] uppercase tracking-wide text-navy/45">
                      Rótulo
                    </span>
                    <input
                      value={point.label}
                      onChange={(e) =>
                        updateGenericPoint(pointIndex, {
                          label: e.target.value,
                        })
                      }
                      className={inputClass}
                      placeholder={
                        kind === "density" ? "Produto" : "Opcional"
                      }
                    />
                  </label>
                  <label className="block text-sm">
                    <span className="text-[11px] uppercase tracking-wide text-navy/45">
                      Fator / ref. antigo
                    </span>
                    <input
                      value={point.oldFactor}
                      onChange={(e) =>
                        updateGenericPoint(pointIndex, {
                          oldFactor: e.target.value,
                        })
                      }
                      className={inputClass}
                    />
                  </label>
                  <label className="block text-sm">
                    <span className="text-[11px] uppercase tracking-wide text-navy/45">
                      Novo valor
                    </span>
                    <input
                      value={point.newValue}
                      onChange={(e) =>
                        updateGenericPoint(pointIndex, {
                          newValue: e.target.value,
                        })
                      }
                      className={inputClass}
                    />
                  </label>
                  {tempFamily ? (
                    <label className="mt-6 flex items-center gap-2 text-sm text-navy">
                      <input
                        type="checkbox"
                        checked={point.isConference}
                        onChange={(e) =>
                          updateGenericPoint(pointIndex, {
                            isConference: e.target.checked,
                          })
                        }
                      />
                      Conferência (após ajuste)
                    </label>
                  ) : (
                    <div className="flex items-end pb-2 text-sm text-navy/60">
                      Erro médio {formatCalibNumber(meanErr, 4)}
                      {measurementUnit ? ` ${measurementUnit}` : ""}
                    </div>
                  )}
                </div>

                <div className="mt-4 space-y-2">
                  <div className="flex items-center justify-between">
                    <p className="text-xs font-semibold uppercase tracking-wide text-navy/45">
                      {tempFamily
                        ? "Pontos (temperaturas) neste ciclo"
                        : "Leituras"}
                    </p>
                    <button
                      type="button"
                      onClick={() =>
                        updateGenericPoint(pointIndex, {
                          cycles: [...point.cycles, emptyCycle()],
                        })
                      }
                      className="text-xs font-semibold text-navy/60 hover:text-navy"
                    >
                      + Leitura
                    </button>
                  </div>
                  {point.cycles.map((cycle, cycleIndex) => {
                    const s = parseCalibNumber(cycle.standard);
                    const i = parseCalibNumber(cycle.instrument);
                    const err = s != null && i != null ? i - s : null;
                    return (
                      <div
                        key={cycle.id}
                        className="grid gap-2 rounded-2xl border border-navy/10 bg-paper/50 p-3 md:grid-cols-5"
                      >
                        <label className="block text-xs">
                          <span className="text-navy/45">Padrão</span>
                          <input
                            value={cycle.standard}
                            onChange={(e) =>
                              updateGenericCycle(pointIndex, cycleIndex, {
                                standard: e.target.value,
                              })
                            }
                            className={inputClass}
                          />
                        </label>
                        <label className="block text-xs">
                          <span className="text-navy/45">Instrumento</span>
                          <input
                            value={cycle.instrument}
                            onChange={(e) =>
                              updateGenericCycle(pointIndex, cycleIndex, {
                                instrument: e.target.value,
                              })
                            }
                            className={inputClass}
                          />
                        </label>
                        <label className="block text-xs">
                          <span className="text-navy/45">
                            {tempFamily ? "T ponto" : "T"}
                          </span>
                          <input
                            value={cycle.temperature}
                            onChange={(e) =>
                              updateGenericCycle(pointIndex, cycleIndex, {
                                temperature: e.target.value,
                              })
                            }
                            className={inputClass}
                          />
                        </label>
                        <div className="flex items-end pb-2 text-xs font-semibold text-navy">
                          Δ {formatCalibNumber(err, 4)}
                        </div>
                        {point.cycles.length > 1 ? (
                          <div className="flex items-end justify-end pb-2">
                            <button
                              type="button"
                              onClick={() =>
                                updateGenericPoint(pointIndex, {
                                  cycles: point.cycles.filter(
                                    (_, i) => i !== cycleIndex,
                                  ),
                                })
                              }
                              className="text-xs text-navy/40 hover:text-red-700"
                            >
                              ×
                            </button>
                          </div>
                        ) : (
                          <div />
                        )}
                      </div>
                    );
                  })}
                </div>
              </article>
            );
          })}
        </section>
      ) : null}

      <div className="flex flex-wrap items-center gap-3">
        <button
          type="submit"
          disabled={pending || !number.trim()}
          className="rounded-xl bg-brass px-5 py-2.5 text-sm font-semibold text-navy hover:bg-brass-2 disabled:opacity-60"
        >
          {pending ? "Salvando…" : "Salvar calibração"}
        </button>
        {error ? <p className="text-sm text-red-700">{error}</p> : null}
        {ok ? <p className="text-sm text-ok">Salvo na planilha.</p> : null}
      </div>
    </form>
  );
}
