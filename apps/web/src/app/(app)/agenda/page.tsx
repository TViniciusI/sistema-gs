import Link from "next/link";
import { formatWorkOrderNumber } from "@gs/shared";
import { PageHeader } from "@/components/ui";
import { agendaDays, getClient } from "@/lib/demo/queries";

export default function AgendaPage() {
  const days = agendaDays();

  return (
    <div>
      <PageHeader
        title="Agenda da equipe"
        description="Distribuição das OS na quinzena — o técnico vê só as suas no aplicativo."
      />
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-7">
        {days.map((day) => (
          <div
            key={day.date}
            className="min-h-36 border border-line bg-white p-3 transition duration-200 hover:border-brass/40"
          >
            <div className="text-xs uppercase tracking-wide text-muted">
              {day.label}
            </div>
            <div className="mt-2 space-y-2">
              {day.orders.length === 0 ? (
                <div className="text-xs text-muted">—</div>
              ) : (
                day.orders.map((os) => {
                  const client = getClient(os.clientId);
                  return (
                    <Link
                      key={os.id}
                      href={`/os/${os.id}`}
                      className="block rounded-sm bg-navy px-2 py-1.5 text-xs text-paper hover:bg-navy-2"
                    >
                      <div className="font-medium">
                        {formatWorkOrderNumber(os.number, os.year)}
                      </div>
                      <div className="text-paper/70">{client?.alias}</div>
                    </Link>
                  );
                })
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
