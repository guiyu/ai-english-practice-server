import { useState, useEffect } from 'react';
import { useRouter } from 'next/router';

export default function Dashboard() {
  const [userData, setUserData] = useState(null);
  const router = useRouter();

  useEffect(() => {
    const fetchData = async () => {
      const res = await fetch('/api/auth/me');
      if (res.ok) {
        setUserData(await res.json());
      } else {
        router.push('/login');
      }
    };
    fetchData();
  }, []);

  return (
    <div className="max-w-4xl mx-auto p-6">
      <h1 className="text-2xl font-bold mb-6">用户仪表盘</h1>
      {userData && (
        <div className="bg-white p-6 rounded-lg shadow">
          <div className="grid grid-cols-2 gap-6">
            <div>
              <h3 className="text-lg font-semibold">账户信息</h3>
              <p>邮箱: {userData.email}</p>
              <p>订阅状态: {userData.plan}</p>
            </div>
            <div>
              <h3 className="text-lg font-semibold">使用情况</h3>
              <p>今日使用次数: {userData.usageCount}/10</p>
              {userData.plan === 'FREE' && (
                <button 
                  onClick={() => router.push('/pricing')}
                  className="mt-4 bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700"
                >
                  升级专业版
                </button>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
