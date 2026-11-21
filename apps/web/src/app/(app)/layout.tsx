import { redirect } from "next/navigation";
import { ROLE_LABELS } from "@gs/shared";
import { AppShell } from "@/components/app-shell";
import { getProfile } from "@/lib/auth";

export default async function AppLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const profile = await getProfile();
  if (!profile) {
    redirect("/login");
  }

  const roleLabel =
    profile.role_label || ROLE_LABELS[profile.role] || profile.role;

  return (
    <AppShell
      name={profile.full_name}
      role={roleLabel}
      source={profile.source}
    >
      {children}
    </AppShell>
  );
}
