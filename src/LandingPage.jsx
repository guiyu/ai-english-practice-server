import React from 'react';
import { useState } from 'react';
import { Menu, X, Check, Volume2, Edit3, Chrome } from 'lucide-react';

const LandingPage = () => {
  const [isMenuOpen, setIsMenuOpen] = useState(false);

  return (
    <div className="min-h-screen bg-white">
      {/* Navigation */}
      <nav className="bg-white border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between h-16">
            <div className="flex items-center">
              <span className="text-2xl font-bold text-blue-600">ChineseHelper</span>
            </div>
            
            {/* Desktop Navigation */}
            <div className="hidden md:flex items-center space-x-8">
              <a href="#features" className="text-gray-700 hover:text-blue-600">功能</a>
              <a href="#pricing" className="text-gray-700 hover:text-blue-600">定价</a>
              <a href="#extension" className="text-gray-700 hover:text-blue-600">安装扩展</a>
              <button className="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700">
                开始使用
              </button>
            </div>

            {/* Mobile menu button */}
            <div className="md:hidden flex items-center">
              <button
                onClick={() => setIsMenuOpen(!isMenuOpen)}
                className="text-gray-700"
              >
                {isMenuOpen ? <X size={24} /> : <Menu size={24} />}
              </button>
            </div>
          </div>
        </div>

        {/* Mobile Navigation */}
        {isMenuOpen && (
          <div className="md:hidden">
            <div className="px-2 pt-2 pb-3 space-y-1">
              <a href="#features" className="block px-3 py-2 text-gray-700">功能</a>
              <a href="#pricing" className="block px-3 py-2 text-gray-700">定价</a>
              <a href="#extension" className="block px-3 py-2 text-gray-700">安装扩展</a>
              <button className="w-full text-left px-3 py-2 bg-blue-600 text-white rounded-lg">
                开始使用
              </button>
            </div>
          </div>
        )}
      </nav>

      {/* Hero Section */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="text-center">
          <h1 className="text-4xl font-bold text-gray-900 sm:text-6xl">
            提升你的中文写作能力
          </h1>
          <p className="mt-4 text-xl text-gray-600">
            智能语法检查，实时语音输出，让学习中文更轻松
          </p>
          <div className="mt-8">
            <button className="bg-blue-600 text-white px-8 py-3 rounded-lg text-lg hover:bg-blue-700">
              免费试用
            </button>
          </div>
        </div>
      </div>

      {/* Features Section */}
      <div id="features" className="bg-gray-50 py-16">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-3xl font-bold text-center text-gray-900">
            强大的功能
          </h2>
          <div className="mt-12 grid grid-cols-1 gap-8 sm:grid-cols-2 lg:grid-cols-3">
            <FeatureCard
              icon={<Edit3 size={24} />}
              title="智能语法纠正"
              description="实时检测并修正语法错误，提供专业的改进建议"
            />
            <FeatureCard
              icon={<Volume2 size={24} />}
              title="语音输出"
              description="标准普通话发音，帮助您提高听说能力"
            />
            <FeatureCard
              icon={<Chrome size={24} />}
              title="浏览器扩展"
              description="便捷的Chrome扩展，随时随地提升写作水平"
            />
          </div>
        </div>
      </div>

      {/* Pricing Section */}
      <div id="pricing" className="py-16">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-3xl font-bold text-center text-gray-900">
            选择适合您的计划
          </h2>
          <div className="mt-12 grid grid-cols-1 gap-8 lg:grid-cols-2">
            <PricingCard
              title="免费版"
              price="0"
              features={[
                "每天10次免费使用机会",
                "基础语法检查",
                "简单的改进建议"
              ]}
              buttonText="开始使用"
              isPrimary={false}
            />
            <PricingCard
              title="专业版"
              price="9.99"
              features={[
                "无限次数使用",
                "高级语法检查",
                "详细的改进建议",
                "语音输出功能",
                "优先客服支持"
              ]}
              buttonText="升级专业版"
              isPrimary={true}
            />
          </div>
        </div>
      </div>
    </div>
  );
};

const FeatureCard = ({ icon, title, description }) => (
  <div className="bg-white p-6 rounded-lg shadow">
    <div className="text-blue-600">{icon}</div>
    <h3 className="mt-4 text-xl font-semibold text-gray-900">{title}</h3>
    <p className="mt-2 text-gray-600">{description}</p>
  </div>
);

const PricingCard = ({ title, price, features, buttonText, isPrimary }) => (
  <div className={`rounded-lg shadow p-8 ${isPrimary ? 'bg-blue-50' : 'bg-white'}`}>
    <h3 className="text-2xl font-semibold text-gray-900">{title}</h3>
    <p className="mt-4">
      <span className="text-4xl font-bold">${price}</span>
      {price !== "0" && <span className="text-gray-600">/月</span>}
    </p>
    <ul className="mt-6 space-y-4">
      {features.map((feature, index) => (
        <li key={index} className="flex items-center">
          <Check size={20} className="text-blue-600" />
          <span className="ml-3 text-gray-600">{feature}</span>
        </li>
      ))}
    </ul>
    <button
      className={`mt-8 w-full py-3 px-4 rounded-lg ${
        isPrimary
          ? 'bg-blue-600 text-white hover:bg-blue-700'
          : 'bg-white text-blue-600 border border-blue-600 hover:bg-blue-50'
      }`}
    >
      {buttonText}
    </button>
  </div>
);

export default LandingPage;