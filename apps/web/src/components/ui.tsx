import Link from "next/link";
import type { ChangeEvent, ReactNode } from "react";

export function PageHeader({
  title,
  description,
  action,
}: {
  title: string;
  description?: string;
  action?: ReactNode;
}) {
  return (
    <div className="mb-6 flex flex-wrap items-end justify-between gap-3">
      <div>
        <h1 className="font-serif text-3xl tracking-tight text-navy">{title}</h1>
        {description ? (
          <p className="mt-1 text-sm text-muted">{description}</p>
        ) : null}
      </div>
      {action}
    </div>
  );
}

export function Button({
  children,
  href,
  variant = "primary",
  type = "button",
  disabled,
  onClick,
}: {
  children: ReactNode;
  href?: string;
  variant?: "primary" | "ghost" | "danger";
  type?: "button" | "submit";
  disabled?: boolean;
  onClick?: () => void;
}) {
  const className =
    variant === "primary"
      ? "inline-flex items-center justify-center rounded-[2px] bg-brass px-3.5 py-2 text-sm font-semibold tracking-wide text-black hover:bg-brass-2 hover:shadow-[0_8px_20px_rgba(197,158,57,0.25)] disabled:opacity-50"
      : variant === "danger"
        ? "inline-flex items-center justify-center rounded-sm bg-danger px-3.5 py-2 text-sm font-medium text-white hover:opacity-90"
        : "inline-flex items-center justify-center rounded-sm border border-line bg-white px-3.5 py-2 text-sm font-medium text-navy hover:bg-paper-2";

  if (href) {
    return (
      <Link href={href} className={className}>
        {children}
      </Link>
    );
  }

  return (
    <button type={type} disabled={disabled} onClick={onClick} className={className}>
      {children}
    </button>
  );
}

export function Field({
  label,
  name,
  type = "text",
  required,
  defaultValue,
  children,
}: {
  label: string;
  name: string;
  type?: string;
  required?: boolean;
  defaultValue?: string | number;
  children?: ReactNode;
}) {
  const controlClass =
    "w-full rounded-sm border border-line bg-white px-3 py-2 text-sm text-ink outline-none focus:border-brass";

  return (
    <label className="block">
      <span className="mb-1 block text-xs font-medium uppercase tracking-wide text-muted">
        {label}
      </span>
      {children ? (
        children
      ) : (
        <input
          name={name}
          type={type}
          required={required}
          defaultValue={defaultValue}
          className={controlClass}
        />
      )}
    </label>
  );
}

export function SelectField({
  label,
  name,
  options,
  defaultValue,
  value,
  required,
  onChange,
}: {
  label: string;
  name: string;
  options: { value: string; label: string }[];
  defaultValue?: string;
  value?: string;
  required?: boolean;
  onChange?: (event: ChangeEvent<HTMLSelectElement>) => void;
}) {
  return (
    <Field label={label} name={name} required={required}>
      <select
        name={name}
        required={required}
        defaultValue={value === undefined ? defaultValue : undefined}
        value={value}
        onChange={onChange}
        className="w-full rounded-sm border border-line bg-white px-3 py-2 text-sm text-ink outline-none focus:border-brass"
      >
        {options.map((option) => (
          <option key={option.value} value={option.value}>
            {option.label}
          </option>
        ))}
      </select>
    </Field>
  );
}

export function DataTable({
  headers,
  rows,
  empty,
}: {
  headers: string[];
  rows: ReactNode[][];
  empty: string;
}) {
  if (rows.length === 0) {
    return (
      <div className="rounded-sm border border-dashed border-line bg-white px-4 py-10 text-center text-sm text-muted">
        {empty}
      </div>
    );
  }

  return (
    <div className="overflow-x-auto rounded-sm border border-line bg-white">
      <table className="w-full text-left text-sm">
        <thead className="border-b border-line bg-paper-2 text-xs uppercase tracking-wide text-muted">
          <tr>
            {headers.map((header) => (
              <th key={header} className="px-3 py-2 font-medium">
                {header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, index) => (
            <tr
              key={index}
              className="border-b border-line last:border-0 transition-colors duration-200 hover:bg-paper/80"
            >
              {row.map((cell, cellIndex) => (
                <td key={cellIndex} className="px-3 py-2.5 align-middle">
                  {cell}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export function StatCard({
  label,
  value,
}: {
  label: string;
  value: string | number;
}) {
  return (
    <div className="rounded-sm border border-line bg-white p-4">
      <div className="font-serif text-3xl text-navy">{value}</div>
      <div className="mt-1 text-xs uppercase tracking-wide text-muted">
        {label}
      </div>
    </div>
  );
}

export function StatusPill({
  label,
  tone = "neutral",
}: {
  label: string;
  tone?: "neutral" | "ok" | "warn" | "danger";
}) {
  const color =
    tone === "ok"
      ? "bg-ok/10 text-ok"
      : tone === "warn"
        ? "bg-brass/15 text-brass"
        : tone === "danger"
          ? "bg-danger/10 text-danger"
          : "bg-navy/5 text-navy/70";
  return (
    <span
      className={`inline-flex px-2 py-0.5 text-[10px] font-medium uppercase tracking-[0.14em] ${color}`}
    >
      {label}
    </span>
  );
}

export function FormGrid({ children }: { children: ReactNode }) {
  return <div className="grid gap-4 sm:grid-cols-2">{children}</div>;
}

export function Panel({ children }: { children: ReactNode }) {
  return (
    <div className="border border-line bg-white p-5 transition-shadow duration-200 hover:shadow-[0_8px_24px_rgba(12,31,51,0.04)]">
      {children}
    </div>
  );
}

export function ErrorText({ message }: { message?: string }) {
  if (!message) return null;
  return <p className="text-sm text-danger">{message}</p>;
}
