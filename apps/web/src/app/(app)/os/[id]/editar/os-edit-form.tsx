"use client";

import { useActionState } from "react";
import {
  updateCampoOsHeader,
  type UpdateOsHeaderState,
} from "@/app/(app)/os/actions";

const initial: UpdateOsHeaderState = {};

export function OsEditForm({
  osId,
  defaults,
}: {
  osId: string;
  defaults: Record<string, string>;
}) {
  const [state, action, pending] = useActionState(updateCampoOsHeader, initial);

  return (
    <form action={action} className="space-y-5">
      <input type="hidden" name="osId" value={osId} />
      {state.error ? (
        <p className="rounded-xl bg-red-50 px-3 py-2 text-sm text-red-700">
          {state.error}
        </p>
      ) : null}
      <div className="grid gap-4 sm:grid-cols-2">
        {(
          [
            ["client", "Cliente"],
            ["cnpj", "CNPJ"],
            ["site", "Local"],
            ["systemType", "Sistema"],
            ["service", "Serviço"],
            ["startsAt", "Início", "date"],
            ["technicianName", "Técnicos (nomes)"],
            ["technicianEmails", "E-mails dos técnicos"],
            ["baseName", "Responsável base"],
            ["baseCargo", "Cargo base"],
            ["baseEmail", "E-mail base"],
            ["basePhone", "Telefone base"],
          ] as Array<[string, string, string?]>
        ).map(([name, label, type]) => (
          <label key={name} className="block text-sm">
            <span className="text-[11px] font-semibold uppercase tracking-wide text-navy/45">
              {label}
            </span>
            <input
              name={name}
              type={type || "text"}
              defaultValue={defaults[name] || ""}
              className="mt-1.5 w-full rounded-xl border border-navy/15 bg-white px-3 py-2.5 text-navy outline-none focus:border-brass"
            />
          </label>
        ))}
      </div>
      <button
        type="submit"
        disabled={pending}
        className="rounded-xl bg-brass px-4 py-2.5 text-sm font-semibold text-navy hover:bg-brass-2 disabled:opacity-60"
      >
        {pending ? "Salvando…" : "Salvar alterações"}
      </button>
    </form>
  );
}
