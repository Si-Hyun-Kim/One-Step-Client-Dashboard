# mcp_agent.py
from anthropic import Anthropic
import asyncio

class SecurityAgent:
    def __init__(self):
        self.ai = Anthropic(api_key="your-key")
        self.mcp_client = MCPClient()
    
    async def auto_generate_rules(self):
        # 1. 로그 분석
        alerts = await self.mcp_client.get_recent_alerts(100)
        
        # 2. AI에게 패턴 분석 요청
        analysis = self.ai.messages.create(
            model="claude-3-5-sonnet-20241022",
            messages=[{
                "role": "user",
                "content": f"""
                다음 보안 알림들을 분석하고 Suricata 룰을 생성해줘:
                {alerts}
                
                반복되는 공격 패턴이 있으면:
                1. 패턴 설명
                2. Suricata 룰 생성
                3. 위험도 평가
                """
            }]
        )
        
        # 3. 생성된 룰 적용
        rule = extract_rule(analysis.content)
        apply_suricata_rule(rule)
        
        return rule