class PurchaseManager {
    constructor() {
        this.stripe = Stripe(window.STRIPE_PUBLISHABLE_KEY);
        this.extensionId = window.EXTENSION_ID;
        this.init();
    }

    init() {
        this.setupEventListeners();
        this.initializeLanguage();
    }

    setupEventListeners() {
        // 购买按钮点击事件
        document.getElementById('checkout-button').addEventListener('click', async () => {
            try {
              // 调用服务端创建Checkout Session
              const response = await fetch('/create-checkout-session', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' }
              });
              
              const session = await response.json();
              
              // 跳转到Stripe支付页面
              const result = await stripe.redirectToCheckout({
                sessionId: session.id
              });
              
              if (result.error) {
                alert(result.error.message);
              }
            } catch (err) {
              console.error('Payment error:', err);
              alert('支付处理失败，请重试');
            }
          });
    }

    async handlePurchase(planType, button) {
        try {
            this.toggleButtonLoading(button, true);

            const response = await fetch('/api/stripe/create-checkout-session', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    planType,
                    extensionId: this.extensionId
                })
            });

            if (!response.ok) {
                throw new Error('Failed to create checkout session');
            }

            const { url } = await response.json();
            window.location.href = url;
        } catch (error) {
            console.error('Purchase error:', error);
            this.showError(i18n.t('error.message'));
        } finally {
            this.toggleButtonLoading(button, false);
        }
    }

    toggleButtonLoading(button, isLoading) {
        button.disabled = isLoading;
        button.classList.toggle('loading', isLoading);
        button.textContent = isLoading 
            ? i18n.t('purchase.processing')
            : i18n.t('purchase.subscribe');
    }

    showError(message) {
        // 实现错误提示UI
        alert(message);
    }

    changeLanguage(lang) {
        localStorage.setItem('preferred_language', lang);
        window.location.reload();
    }

    initializeLanguage() {
        const lang = localStorage.getItem('preferred_language') || 
                    navigator.language.split('-')[0] || 
                    'en';
        
        document.querySelectorAll('.lang-btn').forEach(btn => {
            btn.classList.toggle('active', btn.dataset.lang === lang);
        });
    }
}

// 初始化
document.addEventListener('DOMContentLoaded', () => {
    new PurchaseManager();
});