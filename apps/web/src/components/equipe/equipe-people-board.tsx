"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { StatusPill } from "@/components/ui";
import {
  encodeEquipePersonKey,
  equipePersonKey,
} from "@/lib/campo-data/equipe-keys";
import { campoRoleLabel } from "@/lib/campo-data/labels";
import { UserAdminControls } from "./user-admin-controls";

export type EquipePerson = {
  email: string;
  login: string;
  name: string;
  phone: string;
  role: string;
  status: string;
  active: boolean;
  permissions: string;
  cargo: string;
  funcao: string;
};

export function EquipePeopleBoard({
  people,
  canAdmin,
  empty,
}: {
  people: EquipePerson[];
  canAdmin: boolean;
  empty: string;
}) {
  const [query, setQuery] = useState("");

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return people;
    return people.filter((u) =>
      [u.name, u.login, u.email, u.cargo, u.role, u.phone]
        .join(" ")
        .toLowerCase()
        .includes(q),
    );
  }, [people, query]);

  return (
    <div className="space-y-4">
      <input
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        placeholder="Buscar nome, login, e-mail, cargo…"
        className="w-full rounded-xl border border-navy/10 bg-white px-3.5 py-2.5 text-sm outline-none focus:border-brass"
      />

      {filtered.length === 0 ? (
        <div className="rounded-3xl border border-dashed border-navy/15 bg-white px-4 py-14 text-center text-sm text-muted">
          {empty}
        </div>
      ) : (
        <div className="grid gap-3 lg:grid-cols-2">
          {filtered.map((user) => {
            const key = equipePersonKey(user);
            const href = key
              ? `/equipe/${encodeEquipePersonKey(key)}`
              : null;
            return (
              <article
                key={user.email || user.login}
                className="rounded-3xl border border-navy/10 bg-white p-5 shadow-[0_10px_28px_rgba(12,31,51,0.04)] transition hover:border-brass/35"
              >
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div className="min-w-0">
                    <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-brass">
                      {campoRoleLabel(user.role)}
                    </p>
                    {href ? (
                      <Link
                        href={href}
                        className="mt-1 block font-serif text-xl text-navy hover:text-brass"
                      >
                        {user.name || user.login || "—"}
                      </Link>
                    ) : (
                      <h3 className="mt-1 font-serif text-xl text-navy">
                        {user.name || user.login || "—"}
                      </h3>
                    )}
                    <p className="mt-1 text-sm text-navy/55">
                      {user.login || "—"}
                      {user.email ? ` · ${user.email}` : ""}
                    </p>
                    {user.cargo || user.phone ? (
                      <p className="mt-1 text-xs text-navy/45">
                        {[user.cargo, user.phone].filter(Boolean).join(" · ")}
                      </p>
                    ) : null}
                    {href ? (
                      <Link
                        href={href}
                        className="mt-3 inline-flex text-sm font-semibold text-navy/70 hover:text-navy"
                      >
                        Abrir ficha · documentos e holerites →
                      </Link>
                    ) : null}
                  </div>
                  <div className="flex flex-wrap gap-2">
                    <StatusPill
                      label={user.status}
                      tone={
                        user.status === "aprovado"
                          ? "ok"
                          : user.status === "pendente"
                            ? "warn"
                            : "danger"
                      }
                    />
                    <StatusPill
                      label={user.active ? "Ativo" : "Inativo"}
                      tone={user.active ? "ok" : "neutral"}
                    />
                  </div>
                </div>
                {canAdmin ? (
                  <div className="mt-4 border-t border-navy/8 pt-4">
                    <UserAdminControls
                      email={user.email}
                      login={user.login}
                      status={user.status}
                      role={user.role}
                      active={user.active}
                      permissions={user.permissions}
                      cargo={user.cargo}
                    />
                  </div>
                ) : null}
              </article>
            );
          })}
        </div>
      )}
    </div>
  );
}
