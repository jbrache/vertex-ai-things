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

# ----------- Get Location -----------
get_location_func = FunctionDeclaration(
    name="get_location",
    description="Get latitude and longitude for a given location",
    parameters={
        "type": "object",
        "properties": {
            "poi": {"type": "string", "description": "Point of interest"},
            "street": {"type": "string", "description": "Street name"},
            "city": {"type": "string", "description": "City name"},
            "county": {"type": "string", "description": "County name"},
            "state": {"type": "string", "description": "State name"},
            "country": {"type": "string", "description": "Country name"},
            "postal_code": {"type": "string", "description": "Postal code"},
        },
    },
)

location_tool = Tool(
    function_declarations=[get_location_func],
)

def get_location_coords(
    location_args
):
    """Retrieves the latitude and longitude for a specified location.
    Here we used the OpenStreetMap Nominatim API to geocode an address to make it easy to use 
    and learn in this example. If you're working with large amounts of maps or geolocation data,
    you can use the Google Maps Geocoding API.
    Args:
        location_args: Accepts the arguments extracted from Gemini
    Returns:
        dict: A dictionary containing the location information.
              Example: 
    """

    location_args

    url = "https://nominatim.openstreetmap.org/search?"
    for i in location_args:
        url += '{}="{}"&'.format(i, location_args[i])
    url += "format=json"

    headers = {"User-Agent": "http"}
    response = requests.get(url, headers=headers)
    return response.json()

# ----------------------------------

st.set_page_config(
    page_title="Get Location Coordinates",
    page_icon="vertex-ai.png",
    layout="wide",
)
col1, col2 = st.columns([8, 1])
with col1:
    st.title("Get a locations coordinates")
with col2:
    st.image("vertex-ai.png")
st.subheader("Powered by Function Calling in Gemini")
st.markdown(
    """
    [Documentation](https://cloud.google.com/vertex-ai/docs/generative-ai/multimodal/function-calling)   •   [Codelab](https://codelabs.developers.google.com/codelabs/gemini-function-calling)   •   [Sample Notebook](https://github.com/GoogleCloudPlatform/generative-ai/blob/main/gemini/function-calling/intro_function_calling.ipynb)
    
    Here we used the [OpenStreetMap Nominatim API](https://nominatim.openstreetmap.org/ui/search.html) to geocode an address to make it easy to use and learn in this example. If you're working with large amounts of maps or geolocation data, you can use the [Google Maps Geocoding API](https://developers.google.com/maps/documentation/geocoding).
    """
)

def on_change_checkbox(filter_id):
    print(filter_id)

with st.sidebar:
    location_tool_checkbox = st.checkbox("Location Functions", value=True, help="Test responses with/without function calling")

    temperature = st.slider(
        'Temperature', 
        0.0, 1.0, 0.0,
        help="The temperature is used for sampling during the response generation, which occurs when topP and topK are applied. Temperature controls the degree of randomness in token selection. Lower temperatures are good for prompts that require a more deterministic and less open-ended or creative response, while higher temperatures can lead to more diverse or creative results. A temperature of 0 is deterministic: the highest probability response is always selected."
    )

    # max_tokens = st.slider(
    #     'Max Tokens', 
    #     1, 8192, 2048, 
    #     help="Max response length. Together with your prompt, it shouldn't surpass the model's token limit (8192)"
    # )

    # top_p = st.slider(
    # 'Top P', 
    # 0.0, 1.0, 0.9, 0.01, 
    # help="Adjusts output diversity. Higher values consider more tokens; e.g., 0.8 chooses from the top 80% likely tokens."
    # )

if location_tool_checkbox:
    all_tools = Tool(
        function_declarations=[
            get_location_func,
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
        Location Coordinates Tool
        - I want to get the lat/lon coordinates for the following address: 1600 Amphitheatre Pkwy, Mountain View, CA 94043, US
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
                if response.function_call.name == "get_location":
                    api_response = get_location_coords(params)
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