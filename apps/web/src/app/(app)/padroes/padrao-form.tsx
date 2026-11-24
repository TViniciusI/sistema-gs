"use client";

import { useActionState } from "react";

type State = { error?: string; ok?: boolean };

export function PadraoForm({
  action,
}: {
  action: (prev: State, formData: FormData) => Promise<State>;
}) {
  const [state, formAction, pending] = useActionState(action, {});

  return (
    <form action={formAction} className="grid gap-3 sm:grid-cols-2">
      {state.error ? (
        <p className="sm:col-span-2 text-sm text-red-700">{state.error}</p>
      ) : null}
      {state.ok ? (
        <p className="sm:col-span-2 text-sm text-ok">Padrão salvo.</p>
      ) : null}
      {(
        [
          ["name", "Nome / TAG"],
          ["type", "Tipo"],
          ["serial", "N/S"],
          ["certificate", "Certificado"],
          ["validity", "Validade"],
          ["uncertainty", "Incerteza"],
          ["coverageK", "k cobertura"],
        ] as const
      ).map(([name, label]) => (
        <label key={name} className="block text-sm">
          <span className="text-[11px] uppercase tracking-wide text-navy/45">
            {label}
          </span>
          <input
            name={name}
            required={name === "name"}
            className="mt-1 w-full rounded-xl border border-navy/15 bg-white px-3 py-2 text-navy"
          />
        </label>
      ))}
      <div className="sm:col-span-2">
        <button
          type="submit"
          disabled={pending}
          className="rounded-xl bg-brass px-4 py-2.5 text-sm font-semibold text-navy disabled:opacity-60"
        >
          {pending ? "Salvando…" : "Salvar padrão"}
        </button>
      </div>
    </form>
  );
}
