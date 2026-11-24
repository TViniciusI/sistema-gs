"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState, useTransition, type ReactNode } from "react";
import { logout } from "@/app/login/actions";
import {
  changePasswordAction,
  saveProfileAction,
  setGreetFullNameAction,
} from "@/app/(app)/configuracoes/actions";
import { StatusPill } from "@/components/ui";

const OFFICE_DRIVE = "administrativo@gssolucoestec.com.br";
const CAMPO_URL =
  process.env.NEXT_PUBLIC_CAMPO_URL?.trim() || "https://gs-campo.netlify.app";

const inputClass =
  "mt-1 w-full rounded-xl border border-navy/15 bg-white px-3 py-2.5 text-sm text-navy outline-none focus:border-brass";

export type ConfigDrive = {
  ok: boolean;
  ownerEmail?: string;
  folderName?: string;
  folderUrl?: string;
  wrongOwner?: boolean;
  error?: string;
};

export type ConfigProfile = {
  name: string;
  login: string;
  email: string;
  phone: string;
  roleLabel: string;
  permissions: string;
  source: string;
  canEditCampo: boolean;
};

function officeDriveLabel(account?: string) {
  const raw = (account || "").trim().toLowerCase();
  if (!raw || raw === OFFICE_DRIVE) return OFFICE_DRIVE;
  if (raw.includes("vinicius") || raw.endsWith("@gmail.com")) return OFFICE_DRIVE;
  return raw;
}

export function ConfiguracoesBoard({
  profile,
  drive,
  greetWithFullName,
}: {
  profile: ConfigProfile;
  drive: ConfigDrive;
  greetWithFullName: boolean;
}) {
  const router = useRouter();
  const [greetFull, setGreetFull] = useState(greetWithFullName);
  const [greetPending, startGreet] = useTransition();

  return (
    <div className="space-y-5">
      <section className="rounded-3xl border border-navy/10 bg-gradient-to-br from-white via-white to-paper p-5 md:p-6">
        <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
          Conta ativa
        </p>
        <h2 className="mt-1 font-serif text-3xl text-navy">
          {profile.name || "GS Escritório"}
        </h2>
        <p className="mt-1 text-sm text-navy/55">
          {[profile.roleLabel, profile.login && `@${profile.login}`]
            .filter(Boolean)
            .join(" · ")}
        </p>
        <p className="mt-3 max-w-2xl text-sm leading-6 text-navy/65">
          Ajuste o nome, o usuário de entrada e a senha. A mudança vale nesta
          sessão e, na planilha do GS Campo, no login da empresa.
        </p>
      </section>

      <div className="grid gap-4 lg:grid-cols-2">
        <DrivePanel drive={drive} />

        <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
          <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-brass">
            Sessão
          </p>
          <h3 className="mt-1 font-serif text-xl text-navy">Origem e acesso</h3>
          <dl className="mt-4 space-y-3 text-sm">
            <Row
              label="Origem"
              value={
                profile.source === "campo"
                  ? "Cadastro GS Campo (planilha)"
                  : profile.source === "demo"
                    ? "Sessão demo"
                    : profile.source || "—"
              }
            />
            <Row label="Permissões" value={profile.permissions || "geral"} />
            <Row label="Papel" value={profile.roleLabel || "—"} />
          </dl>
          <div className="mt-5 flex flex-wrap gap-2">
            <Link
              href="/campo"
              className="rounded-xl border border-navy/12 bg-white px-3.5 py-2 text-xs font-medium text-navy hover:border-brass/40"
            >
              App de campo
            </Link>
            <a
              href={CAMPO_URL}
              target="_blank"
              rel="noreferrer"
              className="rounded-xl border border-navy/12 bg-white px-3.5 py-2 text-xs font-medium text-navy hover:border-brass/40"
            >
              Abrir GS Campo
            </a>
            <form action={logout}>
              <button
                type="submit"
                className="rounded-xl bg-navy px-3.5 py-2 text-xs font-semibold text-brass hover:bg-navy-2"
              >
                Sair
              </button>
            </form>
          </div>
        </section>
      </div>

      <ProfileForm profile={profile} />
      <PasswordForm canEdit={profile.canEditCampo} />

      <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
        <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-brass">
          Aparência
        </p>
        <h3 className="mt-1 font-serif text-xl text-navy">Área de trabalho</h3>
        <label className="mt-4 flex cursor-pointer items-start gap-3">
          <input
            type="checkbox"
            className="mt-1"
            checked={greetFull}
            disabled={greetPending}
            onChange={(e) => {
              const next = e.target.checked;
              setGreetFull(next);
              startGreet(async () => {
                await setGreetFullNameAction(next);
                router.refresh();
              });
            }}
          />
          <span>
            <span className="block text-sm font-medium text-navy">
              Saudação com nome completo
            </span>
            <span className="mt-0.5 block text-xs text-navy/50">
              {greetFull
                ? `O início mostra ${profile.name || "o nome inteiro"}.`
                : "O início mostra só o primeiro nome."}
            </span>
          </span>
        </label>
      </section>
    </div>
  );
}

function DrivePanel({ drive }: { drive: ConfigDrive }) {
  const account = officeDriveLabel(drive.ownerEmail);
  const connected = drive.ok;
  const wrongOwner = drive.wrongOwner === true;

  return (
    <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-brass">
            Google Drive
          </p>
          <h3 className="mt-1 font-serif text-xl text-navy">Pasta das OS</h3>
        </div>
        <StatusPill
          label={connected ? (wrongOwner ? "Dono incorreto" : "Conectado") : "Indisponível"}
          tone={connected ? (wrongOwner ? "warn" : "ok") : "danger"}
        />
      </div>
      <p className="mt-3 text-sm leading-6 text-navy/65">
        {connected
          ? wrongOwner
            ? `RDO, fotos e certificados deveriam ir para ${account}, mas o script ainda grava com outra conta.`
            : `RDO, fotos, anexos e certificados vão para a pasta das OS · ${account}.`
          : drive.error || "A pasta das OS no Google Drive não respondeu."}
      </p>
      <dl className="mt-4 space-y-2 text-sm">
        {drive.folderName ? (
          <Row
            label="Pasta"
            value={
              drive.folderUrl ? (
                <a
                  href={drive.folderUrl}
                  target="_blank"
                  rel="noreferrer"
                  className="font-medium text-navy underline-offset-2 hover:underline"
                >
                  {drive.folderName}
                </a>
              ) : (
                drive.folderName
              )
            }
          />
        ) : null}
        <Row label="Conta" value={account} />
      </dl>
      <div className="mt-5 flex flex-wrap gap-2">
        {connected && drive.folderUrl ? (
          <a
            href={drive.folderUrl}
            target="_blank"
            rel="noreferrer"
            className="rounded-xl bg-navy px-3.5 py-2 text-xs font-semibold text-brass hover:bg-navy-2"
          >
            Abrir pasta das OS
          </a>
        ) : null}
        <Link
          href="/arquivos"
          className="rounded-xl border border-navy/12 bg-white px-3.5 py-2 text-xs font-medium text-navy hover:border-brass/40"
        >
          Ver Arquivos / Drive
        </Link>
      </div>
    </section>
  );
}

function ProfileForm({ profile }: { profile: ConfigProfile }) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [ok, setOk] = useState<string | null>(null);

  if (!profile.canEditCampo) {
    return (
      <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
        <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-brass">
          Conta
        </p>
        <h3 className="mt-1 font-serif text-xl text-navy">Perfil</h3>
        <p className="mt-3 text-sm text-navy/55">
          Edição de perfil e senha exige login pelo cadastro GS Campo (planilha).
        </p>
        <dl className="mt-4 grid gap-3 sm:grid-cols-2 text-sm">
          <Row label="Nome" value={profile.name || "—"} />
          <Row label="Usuário" value={profile.login || "—"} />
          <Row label="E-mail" value={profile.email || "—"} />
          <Row label="Telefone" value={profile.phone || "—"} />
        </dl>
      </section>
    );
  }

  return (
    <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
      <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-brass">
        Conta
      </p>
      <h3 className="mt-1 font-serif text-xl text-navy">Perfil</h3>
      <form
        className="mt-4 grid gap-3 sm:grid-cols-2"
        onSubmit={(e) => {
          e.preventDefault();
          const fd = new FormData(e.currentTarget);
          setError(null);
          setOk(null);
          startTransition(async () => {
            const result = await saveProfileAction({}, fd);
            if (result.error) {
              setError(result.error);
              return;
            }
            setOk(result.message || "Perfil salvo.");
            const pwd = e.currentTarget.querySelector<HTMLInputElement>(
              'input[name="password"]',
            );
            if (pwd) pwd.value = "";
            router.refresh();
          });
        }}
      >
        {error ? (
          <p className="sm:col-span-2 text-sm text-red-700">{error}</p>
        ) : null}
        {ok ? <p className="sm:col-span-2 text-sm text-ok">{ok}</p> : null}
        <label className="block text-sm">
          <span className="text-[11px] uppercase tracking-wide text-navy/45">
            Nome
          </span>
          <input
            name="name"
            required
            defaultValue={profile.name}
            className={inputClass}
          />
        </label>
        <label className="block text-sm">
          <span className="text-[11px] uppercase tracking-wide text-navy/45">
            Usuário
          </span>
          <input
            name="login"
            required
            autoComplete="username"
            defaultValue={profile.login}
            className={inputClass}
          />
        </label>
        <label className="block text-sm">
          <span className="text-[11px] uppercase tracking-wide text-navy/45">
            E-mail
          </span>
          <input
            name="email"
            type="email"
            required
            autoComplete="email"
            defaultValue={profile.email}
            className={inputClass}
          />
        </label>
        <label className="block text-sm">
          <span className="text-[11px] uppercase tracking-wide text-navy/45">
            Telefone
          </span>
          <input
            name="phone"
            defaultValue={profile.phone}
            className={inputClass}
          />
        </label>
        <label className="block text-sm sm:col-span-2">
          <span className="text-[11px] uppercase tracking-wide text-navy/45">
            Senha atual
          </span>
          <input
            name="password"
            type="password"
            required
            autoComplete="current-password"
            placeholder="Confirma a troca de usuário"
            className={inputClass}
          />
        </label>
        <div className="sm:col-span-2">
          <button
            type="submit"
            disabled={pending}
            className="rounded-xl bg-brass px-4 py-2.5 text-sm font-semibold text-navy hover:bg-brass-2 disabled:opacity-60"
          >
            {pending ? "Salvando…" : "Salvar conta"}
          </button>
        </div>
      </form>
    </section>
  );
}

function PasswordForm({ canEdit }: { canEdit: boolean }) {
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [ok, setOk] = useState<string | null>(null);

  if (!canEdit) return null;

  return (
    <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
      <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-brass">
        Senha
      </p>
      <h3 className="mt-1 font-serif text-xl text-navy">Trocar senha</h3>
      <p className="mt-2 text-sm text-navy/55">
        A senha atual confirma que é você. A nova vale no escritório e no GS
        Campo.
      </p>
      <form
        className="mt-4 grid gap-3 sm:grid-cols-3"
        onSubmit={(e) => {
          e.preventDefault();
          const form = e.currentTarget;
          const fd = new FormData(form);
          setError(null);
          setOk(null);
          startTransition(async () => {
            const result = await changePasswordAction({}, fd);
            if (result.error) {
              setError(result.error);
              return;
            }
            setOk(result.message || "Senha atualizada.");
            form.reset();
          });
        }}
      >
        {error ? (
          <p className="sm:col-span-3 text-sm text-red-700">{error}</p>
        ) : null}
        {ok ? <p className="sm:col-span-3 text-sm text-ok">{ok}</p> : null}
        <label className="block text-sm">
          <span className="text-[11px] uppercase tracking-wide text-navy/45">
            Senha atual
          </span>
          <input
            name="currentPassword"
            type="password"
            required
            autoComplete="current-password"
            className={inputClass}
          />
        </label>
        <label className="block text-sm">
          <span className="text-[11px] uppercase tracking-wide text-navy/45">
            Senha nova
          </span>
          <input
            name="newPassword"
            type="password"
            required
            autoComplete="new-password"
            className={inputClass}
          />
        </label>
        <label className="block text-sm">
          <span className="text-[11px] uppercase tracking-wide text-navy/45">
            Repetir senha nova
          </span>
          <input
            name="confirmPassword"
            type="password"
            required
            autoComplete="new-password"
            className={inputClass}
          />
        </label>
        <div className="sm:col-span-3">
          <button
            type="submit"
            disabled={pending}
            className="rounded-xl bg-navy px-4 py-2.5 text-sm font-semibold text-brass hover:bg-navy-2 disabled:opacity-60"
          >
            {pending ? "Salvando…" : "Trocar senha"}
          </button>
        </div>
      </form>
    </section>
  );
}

function Row({
  label,
  value,
}: {
  label: string;
  value: ReactNode;
}) {
  return (
    <div className="flex items-baseline justify-between gap-4 border-b border-navy/8 pb-2">
      <dt className="text-[11px] uppercase tracking-wide text-navy/40">
        {label}
      </dt>
      <dd className="text-right text-navy">{value}</dd>
    </div>
  );
}
