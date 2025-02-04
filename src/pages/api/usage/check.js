import prisma from '../../../utils/prisma';
import { usageLimit } from '../../../middleware/usageLimit';

export default usageLimit(async function handler(req, res) {
  // 处理语法检查请求
  const { text } = req.body;
  
  // 调用语法检查服务（示例）
  const corrections = await checkGrammar(text);
  
  // 更新使用次数
  await prisma.user.update({
    where: { id: req.user.userId },
    data: { 
      usageCount: { increment: 1 },
      lastUsedAt: new Date()
    }
  });

  res.status(200).json({ corrections });
});

async function checkGrammar(text) {
  // 实际集成语法检查服务（如HanLP、LTP等）
  return [
    {
      position: [5, 8],
      original: "的得",
      suggestion: "得",
      explanation: "形容词后应该用'得'连接补语"
    }
  ];
}
