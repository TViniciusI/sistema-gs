"use client";

import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { addClienteSystemAction } from "@/app/(app)/clientes/actions";
import { CLIENT_ASSEMBLY_KINDS } from "@/lib/campo-data/labels";

const inputClass =
  "mt-1 w-full rounded-xl border border-navy/15 bg-white px-3 py-2 text-navy outline-none focus:border-brass";

export function AddSystemForm({ clientId }: { clientId: string }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [systemType, setSystemType] = useState("");
  const [installLocation, setInstallLocation] = useState("");
  const [tag, setTag] = useState("");
  const [kind, setKind] = useState("preset");
  const [manufacturer, setManufacturer] = useState("");
  const [model, setModel] = useState("");
  const [serialNumber, setSerialNumber] = useState("");
  const [assemblyTag, setAssemblyTag] = useState("");
  const [meterCount, setMeterCount] = useState(0);
  const [pt100Count, setPt100Count] = useState(0);
  const [densimeterCount, setDensimeterCount] = useState(0);

  if (!open) {
    return (
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="rounded-xl border border-navy/15 bg-white px-4 py-2.5 text-sm font-semibold text-navy hover:border-brass/40"
      >
        + Adicionar sistema
      </button>
    );
  }

  return (
    <form
      className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6 space-y-4"
      onSubmit={(e) => {
        e.preventDefault();
        setError(null);
        startTransition(async () => {
          const result = await addClienteSystemAction({
            clientId,
            system: {
              systemType,
              installLocation,
              tag,
              kind,
              manufacturer,
              model,
              serialNumber,
              assemblyTag,
              meterCount,
              pt100Count,
              densimeterCount,
            },
          });
          if (!result.ok) {
            setError(result.error || "Falha ao salvar.");
            return;
          }
          setOpen(false);
          setSystemType("");
          setInstallLocation("");
          setTag("");
          setKind("preset");
          setManufacturer("");
          setModel("");
          setSerialNumber("");
          setAssemblyTag("");
          setMeterCount(0);
          setPt100Count(0);
          setDensimeterCount(0);
          router.refresh();
        });
      }}
    >
      <div className="flex items-center justify-between gap-3">
        <h3 className="font-serif text-lg text-navy">Novo sistema</h3>
        <button
          type="button"
          onClick={() => setOpen(false)}
          className="text-xs font-medium text-navy/45 hover:text-navy"
        >
          Fechar
        </button>
      </div>
      <div className="grid gap-3 md:grid-cols-2">
        <label className="block text-sm">
          <span className="text-[11px] uppercase tracking-wide text-navy/45">
            Tipo do sistema
          </span>
          <input
            value={systemType}
            onChange={(e) => setSystemType(e.target.value)}
            className={inputClass}
            required
          />
        </label>
        <label className="block text-sm">
          <span className="text-[11px] uppercase tracking-wide text-navy/45">
            Local
          </span>
          <input
            value={installLocation}
            onChange={(e) => setInstallLocation(e.target.value)}
            className={inputClass}
          />
        </label>
        <label className="block text-sm">
          <span className="text-[11px] uppercase tracking-wide text-navy/45">
            TAG
          </span>
          <input
            value={tag}
            onChange={(e) => setTag(e.target.value)}
            className={inputClass}
          />
        </label>
        <label className="block text-sm">
          <span className="text-[11px] uppercase tracking-wide text-navy/45">
            Conjunto
          </span>
          <select
            value={kind}
            onChange={(e) => setKind(e.target.value)}
            className={inputClass}
          >
            {CLIENT_ASSEMBLY_KINDS.map((k) => (
              <option key={k.value} value={k.value}>
                {k.label}
              </option>
            ))}
          </select>
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
            TAG conjunto
          </span>
          <input
            value={assemblyTag}
            onChange={(e) => setAssemblyTag(e.target.value)}
            className={inputClass}
          />
        </label>
        <label className="block text-sm">
          <span className="text-[11px] uppercase tracking-wide text-navy/45">
            Medidores
          </span>
          <input
            type="number"
            min={0}
            value={meterCount}
            onChange={(e) => setMeterCount(Number(e.target.value) || 0)}
            className={inputClass}
          />
        </label>
        <label className="block text-sm">
          <span className="text-[11px] uppercase tracking-wide text-navy/45">
            PT100
          </span>
          <input
            type="number"
            min={0}
            value={pt100Count}
            onChange={(e) => setPt100Count(Number(e.target.value) || 0)}
            className={inputClass}
          />
        </label>
        <label className="block text-sm">
          <span className="text-[11px] uppercase tracking-wide text-navy/45">
            Densímetros
          </span>
          <input
            type="number"
            min={0}
            value={densimeterCount}
            onChange={(e) => setDensimeterCount(Number(e.target.value) || 0)}
            className={inputClass}
          />
        </label>
      </div>
      <div className="flex flex-wrap items-center gap-3">
        <button
          type="submit"
          disabled={pending}
          className="rounded-xl bg-navy px-4 py-2.5 text-sm font-semibold text-paper disabled:opacity-60"
        >
          {pending ? "Salvando…" : "Salvar sistema"}
        </button>
        {error ? <p className="text-sm text-red-700">{error}</p> : null}
      </div>
    </form>
  );
}
