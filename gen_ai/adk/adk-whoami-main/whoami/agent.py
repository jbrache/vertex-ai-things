import sys
import requests

from google.adk.agents.llm_agent import Agent
from google.auth.transport.requests import Request
from google.adk.tools import ToolContext

AUTH_ID = "whoami_auth"
USER_INFO_API = "https://www.googleapis.com/oauth2/v2/userinfo"

def get_user_info(tool_context: ToolContext):
    """
    Return user's information by leveraging token from ToolContext
    """    
    context_token = tool_context.state.get(f"temp:{AUTH_ID}",f"no oauth token found.")
    # print(context_token)

    headers = {'Authorization': f'Bearer {context_token}'}

    try:
        # query user info API using the access token from Tool Context
        response = requests.get(USER_INFO_API, headers=headers)
        # Check for any HTTP errors
        response.raise_for_status() 
    except Exception as e:
        print(f"\n--- An Error Occurred ---", file=sys.stderr)
        print(f"{e}", file=sys.stderr)
        return None
    return response.json()
        
root_agent = Agent(
    model='gemini-2.5-flash',
    name='whoami',
    description='Tell user who he/she is.',
    instruction='Use get_user_info tool to retrieve user\'s information, and tell user who he/she is.',
    tools=[get_user_info]
)