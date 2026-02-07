import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer } from 'recharts';

export const VolumeChart = () => {

    const data = [
        { time: '10:00', volume: 120 },
        { time: '11:00', volume: 200 },
        { time: '12:00', volume: 150 },
        { time: '13:00', volume: 300 },
        { time: '14:00', volume: 180 },
    ];

    return (
        <div className="p-6 bg-slate-900 rounded-xl border border-slate-700">
            <h3 className="text-lg font-bold text-slate-200 mb-4">Volume (24H)</h3>
            <div className="h-[200px]">
                <ResponsiveContainer width="100%" height="100%">
                    <BarChart data={data}>
                        <XAxis dataKey="time" stroke="#64748b" fontSize={12} tickLine={false} axisLine={false} />
                        <YAxis stroke="#64748b" fontSize={12} tickLine={false} axisLine={false} />
                        <Tooltip
                            contentStyle={{ backgroundColor: '#0f172a', borderColor: '#1e293b' }}
                            cursor={{ fill: '#1e293b' }}
                        />
                        <Bar dataKey="volume" fill="#3b82f6" radius={[4, 4, 0, 0]} />
                    </BarChart>
                </ResponsiveContainer>
            </div>
        </div>
    );
};
