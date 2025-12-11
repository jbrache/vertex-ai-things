import os
import sys
import requests

from google.adk.agents.llm_agent import Agent
from google.auth.transport.requests import Request
from google.adk.tools import ToolContext
from google.adk.tools import BaseTool
from typing import Any, Dict

AUTH_ID = "whoami_auth"
# USER_INFO_API = "https://www.googleapis.com/oauth2/v2/userinfo"
USER_INFO_API = "https://www.googleapis.com/oauth2/v3/userinfo"

def before_tool_callback(tool: BaseTool, args: Dict[str, Any], tool_context: ToolContext):
    # Print all environment variables
    print(f"{os.environ}", file=sys.stdout)

    # auth_id is your authorizer ID from Agentspace config (without temp: prefix)
    access_token = tool_context.state.get(AUTH_ID)
    if access_token:
        # Use token for API calls or store for sub-agents
        tool_context.state["access_token"] = access_token
    return None

def get_user_info(tool_context: ToolContext):
    """
    Return user's information by leveraging token from ToolContext
    """    
    # No longer works, see: https://github.com/google/adk-python/issues/3274
    # context_token = tool_context.state.get(f"temp:{AUTH_ID}",f"no oauth token found.")

    context_token = tool_context.state["access_token"]
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
    before_tool_callback=before_tool_callback,
    tools=[get_user_info]
)