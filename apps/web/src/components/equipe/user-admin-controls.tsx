"use client";

import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { updateEquipeUser } from "@/app/(app)/equipe/actions";
import { UserDecideActions } from "./user-decide-actions";

const ROLES = [
  { value: "tecnico", label: "Técnico" },
  { value: "admin", label: "Administrativo" },
  { value: "ambos", label: "Ambos" },
];

export function UserAdminControls({
  email,
  login,
  status,
  role,
  active,
  permissions,
  cargo,
}: {
  email: string;
  login: string;
  status: string;
  role: string;
  active: boolean;
  permissions: string;
  cargo: string;
}) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [roleValue, setRoleValue] = useState(role || "tecnico");
  const [cargoValue, setCargoValue] = useState(cargo || "");
  const [permValue, setPermValue] = useState(permissions || "geral");

  function run(patch: {
    role?: string;
    active?: boolean;
    permissions?: string;
    cargo?: string;
  }) {
    setError(null);
    startTransition(async () => {
      const result = await updateEquipeUser({
        email,
        login,
        ...patch,
      });
      if (!result.ok) {
        setError(result.error || "Falha ao atualizar.");
        return;
      }
      router.refresh();
    });
  }

  return (
    <div className="flex min-w-[220px] flex-col gap-2">
      <UserDecideActions email={email} login={login} status={status} />
      <div className="flex flex-wrap items-center gap-1.5">
        <select
          value={roleValue}
          disabled={pending}
          onChange={(e) => {
            setRoleValue(e.target.value);
            run({ role: e.target.value });
          }}
          className="rounded-lg border border-navy/15 bg-white px-2 py-1 text-[11px] text-navy"
        >
          {ROLES.map((r) => (
            <option key={r.value} value={r.value}>
              {r.label}
            </option>
          ))}
        </select>
        <button
          type="button"
          disabled={pending}
          onClick={() => run({ active: !active })}
          className="rounded-lg border border-navy/15 bg-paper px-2 py-1 text-[11px] font-semibold text-navy hover:border-brass/40 disabled:opacity-60"
        >
          {active ? "Desativar" : "Ativar"}
        </button>
      </div>
      <div className="flex flex-wrap gap-1.5">
        <input
          value={cargoValue}
          onChange={(e) => setCargoValue(e.target.value)}
          placeholder="Cargo"
          className="w-[110px] rounded-lg border border-navy/15 bg-white px-2 py-1 text-[11px] text-navy"
        />
        <button
          type="button"
          disabled={pending}
          onClick={() => run({ cargo: cargoValue })}
          className="rounded-lg bg-navy px-2 py-1 text-[11px] font-semibold text-paper disabled:opacity-60"
        >
          Cargo
        </button>
      </div>
      <div className="flex flex-wrap gap-1.5">
        <input
          value={permValue}
          onChange={(e) => setPermValue(e.target.value)}
          placeholder="permissoes"
          className="w-[110px] rounded-lg border border-navy/15 bg-white px-2 py-1 text-[11px] text-navy"
        />
        <button
          type="button"
          disabled={pending}
          onClick={() => run({ permissions: permValue })}
          className="rounded-lg bg-navy px-2 py-1 text-[11px] font-semibold text-paper disabled:opacity-60"
        >
          Perm.
        </button>
      </div>
      {error ? <p className="text-[11px] text-red-700">{error}</p> : null}
    </div>
  );
}
