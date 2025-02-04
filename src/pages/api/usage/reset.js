import prisma from '../../../utils/prisma'

export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).end()

  try {
    // 每天凌晨重置免费用户使用次数
    await prisma.user.updateMany({
      where: { 
        plan: 'FREE',
        lastResetAt: { 
          lt: new Date(new Date().setHours(0,0,0,0)) 
        }
      },
      data: { 
        usageCount: 0,
        lastResetAt: new Date()
      }
    })

    res.status(200).json({ success: true })
  } catch (error) {
    res.status(500).json({ error: error.message })
  }
}
