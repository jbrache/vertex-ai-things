# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import time
import requests
import os

LOCATION = "us-central1"  # @param {type:"string"}

from google.cloud import bigquery
import streamlit as st
from vertexai.generative_models import FunctionDeclaration, GenerativeModel, Part, Tool
# ----------- Exchange Rates -----------
get_exchange_rate_func = FunctionDeclaration(
    name="get_exchange_rate",
    description="Get the exchange rate for currencies between countries",
    parameters={
    "type": "object",
    "properties": {
        "currency_date": {
            "type": "string",
            "description": "A date that must always be in YYYY-MM-DD format or the value 'latest' if a time period is not specified"
        },
        "currency_from": {
            "type": "string",
            "description": "The currency to convert from in ISO 4217 format"
        },
        "currency_to": {
            "type": "string",
            "description": "The currency to convert to in ISO 4217 format"
        }
    },
         "required": [
            "currency_from",
            "currency_date",
      ]
  },
)
exchange_rate_tool = Tool(
    function_declarations=[get_exchange_rate_func],
)
def get_exchange_rate(
    currency_from: str = "USD",
    currency_to: str = "EUR",
    currency_date: str = "latest",
):
    """Retrieves the exchange rate between two currencies on a specified date.
    Uses the Frankfurter API (https://api.frankfurter.app/) to obtain exchange rate data.
    Args:
        currency_from: The base currency (3-letter currency code). Defaults to "USD" (US Dollar).
        currency_to: The target currency (3-letter currency code). Defaults to "EUR" (Euro).
        currency_date: The date for which to retrieve the exchange rate. Defaults to "latest"
            for the most recent exchange rate data. Can be specified in YYYY-MM-DD format for
            historical rates.
    Returns:
        dict: A dictionary containing the exchange rate information.
              Example: {"amount": 1.0, "base": "USD", "date": "2023-11-24", "rates": {"EUR": 0.95534}}
    """
    response = requests.get(
        f"https://api.frankfurter.app/{currency_date}",
        params={"from": currency_from, "to": currency_to},
    )
    return response.json()
# prompt = """What is the exchange rate from Australian dollars to Swedish krona?
# How much is 500 Australian dollars worth in Swedish krona?"""
# response = model.generate_content(
#     prompt,
#     tools=[exchange_rate_tool],
# )

# ----------------------------------

st.set_page_config(
    page_title="Get Exchange Rates",
    page_icon="vertex-ai.png",
    layout="wide",
)
col1, col2 = st.columns([8, 1])
with col1:
    st.title("Get current and historical exchange rates")
with col2:
    st.image("vertex-ai.png")
st.subheader("Powered by Function Calling in Gemini")
st.markdown(
    "[Documentation](https://cloud.google.com/vertex-ai/docs/generative-ai/multimodal/function-calling)   •   [Codelab](https://codelabs.developers.google.com/codelabs/gemini-function-calling)   •   [Sample Notebook](https://github.com/GoogleCloudPlatform/generative-ai/blob/main/gemini/function-calling/intro_function_calling.ipynb)"
)

def on_change_checkbox(filter_id):
    print(filter_id)

with st.sidebar:
    exchange_tool_checkbox = st.checkbox("Currency Exchange Functions", value=True, help="Test responses with/without function calling")

    temperature = st.slider(
        'Temperature', 
        0.0, 1.0, 0.0,
        help="The temperature is used for sampling during the response generation, which occurs when topP and topK are applied. Temperature controls the degree of randomness in token selection. Lower temperatures are good for prompts that require a more deterministic and less open-ended or creative response, while higher temperatures can lead to more diverse or creative results. A temperature of 0 is deterministic: the highest probability response is always selected."
    )

    # max_tokens = st.slider(
    #     'Max Tokens', 
    #     5, 1000, 500, 
    #     help="Max response length. Together with your prompt, it shouldn't surpass the model's token limit (2048)"
    # )

    # top_p = st.slider(
    # 'Top P', 
    # 0.0, 1.0, 0.9, 0.01, 
    # help="Adjusts output diversity. Higher values consider more tokens; e.g., 0.8 chooses from the top 80% likely tokens."
    # )

if exchange_tool_checkbox:
    all_tools = Tool(
        function_declarations=[
            get_exchange_rate_func,
        ],
    )
else:
    all_tools = None

# ----------------------------------
if all_tools:
    model = GenerativeModel(
        "gemini-1.0-pro",
        generation_config={"temperature": temperature},
        tools=[all_tools],
    )
else:
    model = GenerativeModel(
        "gemini-1.0-pro",
        generation_config={"temperature": temperature},
    )

with st.expander("Sample prompts", expanded=True):
    st.write(
        """
        Currency Exchange Tool
        - What is the exchange rate from Australian dollars to Swedish krona?
        - How much is 500 Australian dollars worth in Swedish krona?
    """
    )
if "messages" not in st.session_state:
    st.session_state.messages = []
for message in st.session_state.messages:
    with st.chat_message(message["role"]):
        st.markdown(message["content"].replace("$", "\$"))  # noqa: W605
        try:
            with st.expander("Function calls, parameters, and responses"):
                st.markdown(message["backend_details"])
        except KeyError:
            pass
if prompt := st.chat_input("Ask me about information in the database..."):
    st.session_state.messages.append({"role": "user", "content": prompt})
    with st.chat_message("user"):
        st.markdown(prompt)
    with st.chat_message("assistant"):
        message_placeholder = st.empty()
        full_response = ""
        chat = model.start_chat()
        print(prompt)
        response = chat.send_message(prompt)
        response = response.candidates[0].content.parts[0]
        print(response)
        api_requests_and_responses = []
        backend_details = ""
        function_calling_in_process = True
        while function_calling_in_process:
            try:
                params = {}
                for key, value in response.function_call.args.items():
                    params[key] = value
                print(response.function_call.name)
                print(params)
                if response.function_call.name == "get_exchange_rate":
                    # api_response = get_exchange_rate(params['currency_from'], params['currency_to'])
                    # print(params['currency_from'])
                    api_response = get_exchange_rate(params['currency_from'], params['currency_to'], params['currency_date'])
                    api_requests_and_responses.append(
                        [response.function_call.name, params, api_response]
                    )
                print(api_response)
                response = chat.send_message(
                    Part.from_function_response(
                        name=response.function_call.name,
                        response={
                            "content": api_response,
                        },
                    ),
                )
                response = response.candidates[0].content.parts[0]
                backend_details += "- Function call:\n"
                backend_details += (
                    "   - Function name: ```"
                    + str(api_requests_and_responses[-1][0])
                    + "```"
                )
                backend_details += "\n\n"
                backend_details += (
                    "   - Function parameters: ```"
                    + str(api_requests_and_responses[-1][1])
                    + "```"
                )
                backend_details += "\n\n"
                backend_details += (
                    "   - API response: ```"
                    + str(api_requests_and_responses[-1][2])
                    + "```"
                )
                backend_details += "\n\n"
                with message_placeholder.container():
                    st.markdown(backend_details)
            except AttributeError:
                function_calling_in_process = False
        time.sleep(3)
        full_response = response.text
        with message_placeholder.container():
            st.markdown(full_response.replace("$", "\$"))  # noqa: W605
            with st.expander("Function calls, parameters, and responses:"):
                st.markdown(backend_details)
        st.session_state.messages.append(
            {
                "role": "assistant",
                "content": full_response,
                "backend_details": backend_details,
            }
        )
def clear_chat_history():
    st.session_state.messages = [{"role": "assistant", "content": "How may I assist you today?"}]
st.sidebar.button('Clear Chat History', on_click=clear_chat_history)