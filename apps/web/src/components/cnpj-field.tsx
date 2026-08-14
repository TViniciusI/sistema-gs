"use client";

import { digitsOnly, maskCnpj } from "@gs/shared";
import { Button } from "@/components/ui";

export function CnpjField({
  value,
  onChange,
  onLookup,
  loading,
  message,
  error,
}: {
  value: string;
  onChange: (value: string) => void;
  onLookup: () => void;
  loading?: boolean;
  message?: string | null;
  error?: string | null;
}) {
  const canLookup = digitsOnly(value).length === 14 && !loading;

  return (
    <label className="block">
      <span className="mb-1 block text-xs font-medium uppercase tracking-wide text-muted">
        CNPJ
      </span>
      <div className="flex gap-2">
        <input
          name="cnpj"
          value={value}
          onChange={(event) => onChange(maskCnpj(event.target.value))}
          onBlur={() => {
            if (canLookup) onLookup();
          }}
          onKeyDown={(event) => {
            if (event.key === "Enter" && canLookup) {
              event.preventDefault();
              onLookup();
            }
          }}
          placeholder="00.000.000/0000-00"
          inputMode="numeric"
          autoComplete="off"
          className="w-full rounded-sm border border-line bg-white px-3 py-2 text-sm text-ink outline-none focus:border-brass"
        />
        <Button
          type="button"
          variant="ghost"
          disabled={!canLookup}
          onClick={onLookup}
        >
          {loading ? "Buscando…" : "Buscar"}
        </Button>
      </div>
      {loading ? (
        <p className="mt-1.5 text-xs text-navy">Consultando CNPJ…</p>
      ) : null}
      {!loading && message ? (
        <p className="mt-1.5 text-xs text-ok">{message}</p>
      ) : null}
      {!loading && error ? (
        <p className="mt-1.5 text-xs text-danger">{error}</p>
      ) : null}
    </label>
  );
}
