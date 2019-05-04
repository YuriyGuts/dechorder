import abc
import os


class PredictionService(object):
    """
    Abstract class for a service that can make chord predictions given audio features.
    """
    @abc.abstractmethod
    def predict(self, df):
        """
        Predict chord labels with confidence.

        Parameters
        ----------
        df : pandas.DataFrame
            Input data frame with audio features.

        Returns
        -------
        pandas.DataFrame
            Prediction data frame with two columns: 'name', 'confidence'.
        """
        pass


class PredictionError(Exception):
    """
    Occurs when chord predictions cannot be made.
    """
    pass


def get_prediction_service(service_key):
    """
    Instantiates a prediction service by its key.

    Parameters
    ----------
    service_key : str
        The class name for the service.

    Returns
    -------
    An instance of PredictionService
    """
    if service_key == 'DataRobotV1APIPredictionService':
        from common.predictions.datarobot import DataRobotV1APIPredictionService
        return DataRobotV1APIPredictionService(
            server=os.environ['DATAROBOT_SERVER'],
            server_key=os.environ['DATAROBOT_SERVER_KEY'],
            deployment_id=os.environ['DATAROBOT_DEPLOYMENT_ID'],
            username=os.environ['DATAROBOT_USERNAME'],
            api_token=os.environ['DATAROBOT_API_TOKEN'],
        )

    elif service_key == 'EmbeddedPredictionService':
        from common.predictions.embedded import EmbeddedPredictionService
        return EmbeddedPredictionService()

    elif service_key == 'DummyPredictionService':
        from common.predictions.dummy import DummyPredictionService
        return DummyPredictionService(random_state=42)

    else:
        raise ValueError(f'Unknown prediction service: {service_key}')
