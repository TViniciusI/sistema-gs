"use client";

import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { updateClienteAction } from "../actions";

export function ClientEditForm({
  clientId,
  defaults,
}: {
  clientId: string;
  defaults: {
    name: string;
    requester: string;
    city: string;
    state: string;
    baseName: string;
    baseCargo: string;
    baseEmail: string;
    basePhone: string;
    sites: string;
  };
}) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [ok, setOk] = useState(false);
  const [values, setValues] = useState(defaults);

  function set(key: keyof typeof values, value: string) {
    setValues((prev) => ({ ...prev, [key]: value }));
  }

  return (
    <form
      className="space-y-3"
      onSubmit={(e) => {
        e.preventDefault();
        setError(null);
        setOk(false);
        startTransition(async () => {
          const result = await updateClienteAction({
            clientId,
            ...values,
          });
          if (!result.ok) {
            setError(result.error || "Falha ao salvar.");
            return;
          }
          setOk(true);
          router.refresh();
        });
      }}
    >
      {(
        [
          ["name", "Razão / nome"],
          ["requester", "Solicitante"],
          ["city", "Cidade"],
          ["state", "UF"],
          ["baseName", "Responsável base"],
          ["baseCargo", "Cargo"],
          ["baseEmail", "E-mail"],
          ["basePhone", "Telefone"],
          ["sites", "Sites (separados por |)"],
        ] as const
      ).map(([key, label]) => (
        <label key={key} className="block text-sm">
          <span className="text-[11px] uppercase tracking-wide text-navy/45">
            {label}
          </span>
          <input
            value={values[key]}
            onChange={(e) => set(key, e.target.value)}
            className="mt-1 w-full rounded-xl border border-navy/15 bg-white px-3 py-2 text-navy"
          />
        </label>
      ))}
      <button
        type="submit"
        disabled={pending}
        className="rounded-xl bg-brass px-4 py-2.5 text-sm font-semibold text-navy disabled:opacity-60"
      >
        {pending ? "Salvando…" : "Salvar cadastro"}
      </button>
      {error ? <p className="text-sm text-red-700">{error}</p> : null}
      {ok ? <p className="text-sm text-ok">Salvo na planilha.</p> : null}
    </form>
  );
}
